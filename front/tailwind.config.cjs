/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html", "./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#0f172a",
        panel: "#111827",
        soft: "#1f2937",
        primary: "#60a5fa",
        accent: "#34d399"
      }
    },
  },
  plugins: [],
};
