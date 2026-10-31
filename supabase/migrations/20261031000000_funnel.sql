-- "आपका अच्छा समय" lead funnel: tables, row-level security and the staff RPCs.
--
-- The binding spec is docs/funnel/CONTRACT.md. The shape of the security:
--   * anon (the public key on the landing page) can touch nothing here. Leads
--     and events are written only by the edge functions, with the service role.
--   * Signed-in staff may SELECT what their role allows, enforced by RLS.
--     They change nothing directly: every write goes through a SECURITY
--     DEFINER function below, which checks the role, writes the change and
--     leaves a line in lead_activity (and audit_log where it matters).
--   * lead_secrets has RLS on and no policy and no grant at all, so the only
--     way to a PDF password is reveal_password(), which logs who asked.
-- These rows are personal data under India's DPDP Act; keep it that way.

-- ---------------------------------------------------------------------------
-- Types

create type public.lead_status as enum
  ('new', 'contacted', 'interested', 'paid', 'not_interested', 'invalid');
create type public.staff_role as enum ('owner', 'manager', 'caller');
create type public.activity_kind as enum ('note', 'status', 'call', 'payment', 'assign');
create type public.lead_event_kind as enum
  ('basis_open', 'pdf_download', 'whatsapp_click', 'call_click');

-- ---------------------------------------------------------------------------
-- Tables

create table public.staff (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 80),
  role       public.staff_role not null default 'caller',
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.leads (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique check (code ~ '^KS-[0-9]{6}$'),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  -- Personal fields are nullable only so erase_lead() can blank them; the
  -- edge function always fills them.
  name            text,
  phone           text,
  birth_date      date,
  birth_time      time,
  time_approx     boolean not null default false,
  place_name      text,
  lat             double precision,
  lon             double precision,
  tz              text,
  utc_offset_min  integer,
  kundli          jsonb,
  lang            text not null default 'hi',
  src             text,
  utm_source      text,
  utm_medium      text,
  utm_campaign    text,
  referrer        text,
  landing_url     text,
  ip              inet,
  user_agent      text,
  consent_at      timestamptz,
  consent_version text,
  status          public.lead_status not null default 'new',
  assigned_to     uuid references public.staff (user_id) on delete set null,
  amount_paid     integer not null default 0 check (amount_paid >= 0),
  paid_at         timestamptz,
  deleted_at      timestamptz
);

create table public.lead_secrets (
  lead_id      uuid primary key references public.leads (id) on delete cascade,
  pdf_password text not null
);

create table public.lead_events (
  id         bigint generated always as identity primary key,
  lead_id    uuid not null references public.leads (id) on delete cascade,
  event      public.lead_event_kind not null,
  created_at timestamptz not null default now(),
  ip         inet,
  user_agent text
);

create table public.lead_activity (
  id         bigint generated always as identity primary key,
  lead_id    uuid not null references public.leads (id) on delete cascade,
  actor      uuid references public.staff (user_id) on delete set null,
  kind       public.activity_kind not null,
  text       text,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id      bigint generated always as identity primary key,
  actor   uuid,            -- no foreign key: the trail outlives the account
  action  text not null,
  lead_id uuid,            -- likewise kept if the lead row ever goes
  detail  jsonb not null default '{}'::jsonb,
  at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes: the admin list (newest first, by status/src/assignee), the edge
-- function's rate limit (ip + time) and dedupe (phone + birth), timelines.

create index leads_created_idx   on public.leads (created_at desc);
create index leads_status_idx    on public.leads (status, created_at desc);
create index leads_src_idx       on public.leads (src, created_at desc);
create index leads_assigned_idx  on public.leads (assigned_to, created_at desc);
create index leads_ip_idx        on public.leads (ip, created_at desc);
create index leads_dedupe_idx    on public.leads (phone, birth_date, created_at desc)
  where deleted_at is null;
create index lead_events_lead_idx   on public.lead_events (lead_id, created_at);
create index lead_events_kind_idx   on public.lead_events (event, lead_id);
create index lead_activity_lead_idx on public.lead_activity (lead_id, created_at);
create index audit_log_lead_idx     on public.audit_log (lead_id, at);
create index audit_log_at_idx       on public.audit_log (at desc);

-- ---------------------------------------------------------------------------
-- updated_at

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger leads_touch before update on public.leads
  for each row execute function public.touch_updated_at();
create trigger staff_touch before update on public.staff
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Role helpers. SECURITY DEFINER so the RLS policies can call them without
-- recursing into staff's own policy.

create function public.current_staff_role() returns public.staff_role
language sql stable security definer set search_path = public as $$
  select role from public.staff where user_id = auth.uid() and active
$$;

-- Whether the caller may see (and so work) this lead: owner/manager see all
-- live leads, a caller sees the ones assigned to them and the unassigned.
create function public.can_see_lead(lead uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.leads l
    where l.id = lead and l.deleted_at is null
      and case public.current_staff_role()
            when 'owner'   then true
            when 'manager' then true
            when 'caller'  then l.assigned_to is null or l.assigned_to = auth.uid()
            else false
          end
  )
$$;

-- ---------------------------------------------------------------------------
-- Row-level security and grants.
--
-- Supabase's default privileges grant everything on new tables to anon and
-- authenticated; RLS alone would then be the only wall. Revoking as well
-- means a forgotten policy fails closed.

alter table public.staff         enable row level security;
alter table public.leads         enable row level security;
alter table public.lead_secrets  enable row level security;
alter table public.lead_events   enable row level security;
alter table public.lead_activity enable row level security;
alter table public.audit_log     enable row level security;

revoke all on public.staff, public.leads, public.lead_secrets, public.lead_events,
  public.lead_activity, public.audit_log from public, anon, authenticated;

grant select on public.staff, public.leads, public.lead_events,
  public.lead_activity, public.audit_log to authenticated;
-- lead_secrets: deliberately no grant to authenticated.

grant all on public.staff, public.leads, public.lead_secrets, public.lead_events,
  public.lead_activity, public.audit_log to service_role;

-- Active staff see the team (names and roles, for assignment).
create policy staff_select on public.staff for select to authenticated
  using ((select public.current_staff_role()) is not null);

create policy leads_select on public.leads for select to authenticated
  using (
    deleted_at is null and (
      (select public.current_staff_role()) in ('owner', 'manager')
      or ((select public.current_staff_role()) = 'caller'
          and (assigned_to is null or assigned_to = (select auth.uid())))
    )
  );

create policy lead_events_select on public.lead_events for select to authenticated
  using (public.can_see_lead(lead_id));

create policy lead_activity_select on public.lead_activity for select to authenticated
  using (public.can_see_lead(lead_id));

-- The audit trail is the owner's: it records what staff did.
create policy audit_log_select on public.audit_log for select to authenticated
  using ((select public.current_staff_role()) = 'owner');

-- ---------------------------------------------------------------------------
-- Internal helpers for the RPCs

-- The caller's role, or an error if they are not active staff.
create function public.require_staff() returns public.staff_role
language plpgsql stable security definer set search_path = public as $$
declare r public.staff_role;
begin
  r := public.current_staff_role();
  if r is null then
    raise exception 'not_staff' using errcode = '42501';
  end if;
  return r;
end $$;

-- Locks the lead row for the rest of the transaction after checking the
-- caller may work it, so two people changing one lead do not interleave.
create function public.lock_visible_lead(lead uuid) returns public.leads
language plpgsql security definer set search_path = public as $$
declare l public.leads;
begin
  perform public.require_staff();
  if not public.can_see_lead(lead) then
    raise exception 'lead_not_found' using errcode = 'P0002';
  end if;
  select * into l from public.leads where id = lead for update;
  return l;
end $$;

create function public.log_activity(lead uuid, k public.activity_kind, t text) returns void
language sql security definer set search_path = public as $$
  insert into public.lead_activity (lead_id, actor, kind, text) values (lead, auth.uid(), k, t)
$$;

create function public.log_audit(act text, lead uuid, d jsonb) returns void
language sql security definer set search_path = public as $$
  insert into public.audit_log (actor, action, lead_id, detail)
  values (auth.uid(), act, lead, coalesce(d, '{}'::jsonb))
$$;

-- ---------------------------------------------------------------------------
-- Staff RPCs

-- The PDF password. A refusal is not an error but a NULL, so that the attempt
-- can still be written to audit_log (an exception would roll the log back).
create function public.reveal_password(lead uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  pw text;
  c  text;
begin
  perform public.require_staff();
  select code into c from public.leads where id = lead;
  if not public.can_see_lead(lead) then
    perform public.log_audit('reveal_password_denied', lead, jsonb_build_object('code', c));
    return null;
  end if;
  select pdf_password into pw from public.lead_secrets where lead_id = lead;
  perform public.log_audit('reveal_password', lead, jsonb_build_object('code', c));
  return pw;
end $$;

-- Any active staff member may take an unassigned lead for themselves.
create function public.take_lead(lead uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l public.leads;
begin
  l := public.lock_visible_lead(lead);
  if l.assigned_to = auth.uid() then
    return;
  end if;
  if l.assigned_to is not null then
    raise exception 'already_assigned' using errcode = 'P0001';
  end if;
  update public.leads set assigned_to = auth.uid() where id = lead;
  perform public.log_activity(lead, 'assign', 'लीड ली / took the lead');
end $$;

-- A caller who works an unassigned lead takes it at the same time, so that
-- two callers do not ring the same person.
create function public.claim_if_unassigned(l public.leads) returns void
language plpgsql security definer set search_path = public as $$
begin
  if l.assigned_to is null and public.current_staff_role() = 'caller' then
    update public.leads set assigned_to = auth.uid() where id = l.id;
    perform public.log_activity(l.id, 'assign', 'लीड ली / took the lead');
  end if;
end $$;

create function public.set_lead_status(lead uuid, new_status public.lead_status, note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  l public.leads;
  n text := nullif(btrim(coalesce(note, '')), '');
begin
  if char_length(n) > 2000 then
    raise exception 'note_too_long' using errcode = '22001';
  end if;
  l := public.lock_visible_lead(lead);
  perform public.claim_if_unassigned(l);
  if l.status = new_status and n is null then
    return;
  end if;
  update public.leads set status = new_status where id = lead;
  perform public.log_activity(lead, 'status',
    l.status::text || ' → ' || new_status::text || coalesce(': ' || n, ''));
end $$;

-- Payments add up (report now, consultation later); paid_at is the latest.
create function public.record_payment(lead uuid, amount int, note text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare
  l public.leads;
  n text := nullif(btrim(coalesce(note, '')), '');
begin
  if amount is null or amount <= 0 or amount > 1000000 then
    raise exception 'bad_amount' using errcode = '22023';
  end if;
  if char_length(n) > 2000 then
    raise exception 'note_too_long' using errcode = '22001';
  end if;
  l := public.lock_visible_lead(lead);
  perform public.claim_if_unassigned(l);
  update public.leads
     set amount_paid = amount_paid + amount, paid_at = now(), status = 'paid'
   where id = lead;
  perform public.log_activity(lead, 'payment', '₹' || amount || coalesce(' — ' || n, ''));
  perform public.log_audit('record_payment', lead,
    jsonb_build_object('code', l.code, 'amount', amount, 'total', l.amount_paid + amount));
end $$;

create function public.add_note(lead uuid, text text) returns void
language plpgsql security definer set search_path = public as $$
declare n text := nullif(btrim(coalesce(text, '')), '');
begin
  if n is null then
    raise exception 'empty_note' using errcode = '22023';
  end if;
  if char_length(n) > 2000 then
    raise exception 'note_too_long' using errcode = '22001';
  end if;
  perform public.lock_visible_lead(lead);
  perform public.log_activity(lead, 'note', n);
end $$;

-- The admin panel's Call button records that a call was placed, so the
-- history shows attempts as well as outcomes.
create function public.log_call(lead uuid, note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare n text := nullif(btrim(coalesce(note, '')), '');
begin
  if char_length(n) > 2000 then
    raise exception 'note_too_long' using errcode = '22001';
  end if;
  perform public.lock_visible_lead(lead);
  perform public.log_activity(lead, 'call', coalesce(n, 'कॉल किया / called'));
end $$;

-- Manager/owner: assign to an active staff member, or NULL to unassign.
create function public.assign_lead(lead uuid, staff_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  l public.leads;
  who text;
begin
  if public.require_staff() not in ('owner', 'manager') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  l := public.lock_visible_lead(lead);
  if staff_user is not null then
    select name into who from public.staff where user_id = staff_user and active;
    if who is null then
      raise exception 'no_such_staff' using errcode = 'P0002';
    end if;
  end if;
  if l.assigned_to is not distinct from staff_user then
    return;
  end if;
  update public.leads set assigned_to = staff_user where id = lead;
  perform public.log_activity(lead, 'assign', coalesce('→ ' || who, 'अनअसाइन / unassigned'));
  perform public.log_audit('assign_lead', lead,
    jsonb_build_object('code', l.code, 'from', l.assigned_to, 'to', staff_user));
end $$;

-- Owner: an erasure request under the DPDP Act. The row stays so counts by
-- day and by flyer do not change, but everything that identifies the person
-- goes: the personal fields, the password, the IPs on their events and the
-- free text staff wrote about them.
create function public.erase_lead(lead uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if public.require_staff() <> 'owner' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select code into c from public.leads where id = lead and deleted_at is null for update;
  if c is null then
    raise exception 'lead_not_found' using errcode = 'P0002';
  end if;
  update public.leads set
    deleted_at = now(),
    name = null, phone = null, birth_date = null, birth_time = null,
    place_name = null, lat = null, lon = null, tz = null, utc_offset_min = null,
    kundli = null, utm_source = null, utm_medium = null, utm_campaign = null,
    referrer = null, landing_url = null, ip = null, user_agent = null,
    assigned_to = null
  where id = lead;
  delete from public.lead_secrets where lead_id = lead;
  update public.lead_events set ip = null, user_agent = null where lead_id = lead;
  update public.lead_activity set text = null where lead_id = lead;
  perform public.log_audit('erase_lead', lead, jsonb_build_object('code', c));
end $$;

-- Manager/owner: a CSV export takes personal data off the server, so the
-- admin panel records each one (how many rows, which filters).
create function public.log_export(row_count int, filters jsonb default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.require_staff() not in ('owner', 'manager') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform public.log_audit('export_csv', null,
    jsonb_build_object('rows', row_count, 'filters', coalesce(filters, '{}'::jsonb)));
end $$;

-- Manager/owner: the dashboard. Counts are over leads created in
-- [from_ts, to_ts) — a cohort — so "paid" and "downloads" answer "of the
-- people this flyer brought in, how many went on to…". Erased leads still
-- count. Days are IST calendar days.
create function public.lead_stats(from_ts timestamptz, to_ts timestamptz) returns json
language plpgsql stable security definer set search_path = public as $$
declare result json;
begin
  if public.require_staff() not in ('owner', 'manager') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  with cohort as (
    select l.*,
           exists (select 1 from public.lead_events e
                   where e.lead_id = l.id and e.event = 'pdf_download') as downloaded,
           l.status in ('contacted', 'interested', 'paid', 'not_interested') as contacted
      from public.leads l
     where l.created_at >= from_ts and l.created_at < to_ts
  )
  select json_build_object(
    'from', from_ts,
    'to', to_ts,
    'totals', (select json_build_object(
        'leads', count(*),
        'downloads', count(*) filter (where downloaded),
        'contacted', count(*) filter (where contacted),
        'paid', count(*) filter (where amount_paid > 0),
        'revenue', coalesce(sum(amount_paid), 0)
      ) from cohort),
    'by_day', coalesce((select json_agg(d order by d.day) from (
        select (created_at at time zone 'Asia/Kolkata')::date as day,
               count(*) as leads,
               count(*) filter (where downloaded) as downloads,
               count(*) filter (where amount_paid > 0) as paid
          from cohort group by 1) d), '[]'::json),
    'by_src', coalesce((select json_agg(s order by s.leads desc, s.src) from (
        select coalesce(nullif(src, ''), '(none)') as src,
               count(*) as leads,
               count(*) filter (where downloaded) as downloads,
               count(*) filter (where contacted) as contacted,
               count(*) filter (where amount_paid > 0) as paid,
               coalesce(sum(amount_paid), 0) as revenue
          from cohort group by 1) s), '[]'::json),
    'by_status', coalesce((select json_object_agg(status, n) from (
        select status, count(*) as n from cohort group by 1) st), '{}'::json)
  ) into result;
  return result;
end $$;

-- ---------------------------------------------------------------------------
-- Service-role helpers for the edge functions

-- Inserts a lead and its password in one transaction, so a lead never exists
-- without the password its visitor was shown.
create function public.funnel_create_lead(lead jsonb, password text) returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  insert into public.leads (
    code, name, phone, birth_date, birth_time, time_approx, place_name, lat, lon,
    tz, utc_offset_min, kundli, lang, src, utm_source, utm_medium, utm_campaign,
    referrer, landing_url, ip, user_agent, consent_at, consent_version
  ) values (
    lead->>'code', lead->>'name', lead->>'phone', (lead->>'birth_date')::date,
    (lead->>'birth_time')::time, coalesce((lead->>'time_approx')::boolean, false),
    lead->>'place_name', (lead->>'lat')::double precision, (lead->>'lon')::double precision,
    lead->>'tz', (lead->>'utc_offset_min')::integer,
    case when jsonb_typeof(lead->'kundli') = 'object' then lead->'kundli' end,
    coalesce(lead->>'lang', 'hi'), lead->>'src', lead->>'utm_source', lead->>'utm_medium',
    lead->>'utm_campaign', lead->>'referrer', lead->>'landing_url',
    (lead->>'ip')::inet, lead->>'user_agent', now(), lead->>'consent_version'
  ) returning id into new_id;
  insert into public.lead_secrets (lead_id, pdf_password) values (new_id, password);
  return new_id;
end $$;

-- manage-staff adds people who already have an account by email.
create function public.staff_user_id_by_email(email text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from auth.users where lower(auth.users.email) = lower(staff_user_id_by_email.email) limit 1
$$;

-- ---------------------------------------------------------------------------
-- Function privileges. Postgres grants EXECUTE to PUBLIC and Supabase also to
-- anon, so revoke from both and grant back only what each role needs.

revoke execute on function
  public.touch_updated_at(),
  public.current_staff_role(),
  public.can_see_lead(uuid),
  public.require_staff(),
  public.lock_visible_lead(uuid),
  public.log_activity(uuid, public.activity_kind, text),
  public.log_audit(text, uuid, jsonb),
  public.claim_if_unassigned(public.leads),
  public.reveal_password(uuid),
  public.take_lead(uuid),
  public.set_lead_status(uuid, public.lead_status, text),
  public.record_payment(uuid, int, text),
  public.add_note(uuid, text),
  public.log_call(uuid, text),
  public.assign_lead(uuid, uuid),
  public.erase_lead(uuid),
  public.log_export(int, jsonb),
  public.lead_stats(timestamptz, timestamptz),
  public.funnel_create_lead(jsonb, text),
  public.staff_user_id_by_email(text)
from public, anon, authenticated;

-- What the admin panel calls. Each checks the role itself; a signed-in user
-- who is not staff gets 'not_staff'.
grant execute on function
  public.current_staff_role(),
  public.can_see_lead(uuid),
  public.reveal_password(uuid),
  public.take_lead(uuid),
  public.set_lead_status(uuid, public.lead_status, text),
  public.record_payment(uuid, int, text),
  public.add_note(uuid, text),
  public.log_call(uuid, text),
  public.assign_lead(uuid, uuid),
  public.erase_lead(uuid),
  public.log_export(int, jsonb),
  public.lead_stats(timestamptz, timestamptz)
to authenticated;

grant execute on function
  public.funnel_create_lead(jsonb, text),
  public.staff_user_id_by_email(text)
to service_role;

-- ---------------------------------------------------------------------------
-- Bootstrap: making the first owner.
--
-- 1. Supabase dashboard → Authentication → Users → "Add user" with your
--    email and a password (tick "Auto Confirm User").
-- 2. SQL Editor → run, with your email:
--
--   insert into staff(user_id,name,role) select id,'Owner','owner' from auth.users where email='you@example.com';
--
-- After that, add everyone else from the admin panel's Staff screen.
