// Public settings for the landing page and the admin panel. The deploy
// workflow rewrites this file from the repository's variables; these empty
// values mean "backend not set up yet", and the pages say so instead of
// breaking. The anon key is public by design: the database's row-level
// security, not this key, is what protects the data.
window.KS_CONFIG = {
  supabaseUrl: "https://zhxjaipfleyfbnxohzbo.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpoeGphaXBmbGV5ZmJueG9oemJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM0NzA1NzcsImV4cCI6MjEwOTA0NjU3N30.ktwQHZeF5deGs_r3-xLDHbHNKx6YQ-nAfNK2DF5miDc",
  baseUrl: "https://pallavsharmaofficial.github.io/KundliSaar",
  contactPhone: "9910144125",
  whatsappPhone: "919910144125",
  upiId: "pallavsharma353-1@okaxis",
  upiName: "Pallav Sharma",
  passwordPrice: 199,
};
