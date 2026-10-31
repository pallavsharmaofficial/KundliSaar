// Public settings for the landing page and the admin panel. The deploy
// workflow rewrites this file from the repository's variables; these empty
// values mean "backend not set up yet", and the pages say so instead of
// breaking. The anon key is public by design: the database's row-level
// security, not this key, is what protects the data.
window.KS_CONFIG = {
  supabaseUrl: "",
  supabaseAnonKey: "",
  baseUrl: "https://pallavsharmaofficial.github.io/KundliSaar",
  contactPhone: "9910144125",
  whatsappPhone: "919910144125",
  upiId: "pallavsharma353-1@okaxis",
  upiName: "Pallav Sharma",
  passwordPrice: 199,
};
