/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './*.html',
    './apps/*.html',
  ],
  theme: {
    extend: {
      colors: {
        'w-bg': '#0a0806',
        'w-bg2': '#110e09',
        'w-card': '#1a1410',
        'w-card-h': '#221b13',
        'w-gold': '#c8941a',
        'w-gold-b': '#f0b830',
        'w-gold-dim': '#c8941a22',
        'w-gold-glow': '#c8941a44',
        'w-text': '#f0e8d8',
        'w-text2': '#a09070',
        'w-dim': '#5a4a30',
        'w-border': '#2e2318',
        'w-border-g': '#c8941a44',
        'w-green': '#7ec87e',
      }
    }
  },
  plugins: [],
}
