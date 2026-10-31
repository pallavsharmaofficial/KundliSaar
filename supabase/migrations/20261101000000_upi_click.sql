-- The landing page now offers the ₹199 password by UPI as well as by call or
-- WhatsApp; the tap on that button is recorded like the others.
alter type public.lead_event_kind add value if not exists 'upi_click';
