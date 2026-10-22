# Titli

**Bolo, aur Titli yaad rakhegi.** Titli is a voice memory assistant for people who find phones hard to use. You say what happened in Hindi or Hinglish, and Titli remembers it. Later you ask, and Titli answers, out loud.

- *"Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge"* → saved as ₹2,000 given to Ramesh bhaiya, due Diwali
- *"Aadhaar card almari ke drawer mein rakha hai"* → saved as a document and where it is
- *"Kal 10 baje gas cylinder book karna yaad dilana"* → saved as a reminder
- *"Ramesh ko kitna diya tha?"* → "Ramesh bhaiya se 3,500 rupaye lene baaki hain", with a WhatsApp nudge button

Works in Devanagari and Roman script. Everything stays on the phone (localStorage). No sign-up, no server.

## Run it

It is a static site. Open it on GitHub Pages, or locally:

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

Voice input needs Chrome (Android or desktop). On other browsers, tap **Aa** to type. Demo links: `?say=Imran se 1200 liye`.

## Files

- `index.html`, `styles.css`: the Titli Bento UI
- `app.js`: screens (home, listening, saved, answer), voice, speech, storage
- `brain.js`: Hindi/Hinglish understanding (amounts like "dhai hazaar", people, dates like "Diwali tak", documents and places)
- `hero.js`: the live 3D titli (three.js) whose flight trail carries your memories as pearls
- `assets/`: pre-rendered 3D objects for the tiles
