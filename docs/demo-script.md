# Live demo script (two devices)

Before the demo:
- In the app, sign in as **Sara Idrissi** (administrator), then choose *Changer de rôle → Remettre la démo à zéro*.
- Open the app on a phone and on a laptop.

1. **Laptop: sign in as Mehdi Tazi** (Responsable des Studios). Open *Validations*: requests waiting, oldest first.
2. **Phone: sign in as Yasmine Mansouri** (student). Go to *Studios → Studio Podcast → Réserver*. Pick a free hour, choose an activity, and send.
   - The slot now shows "En attente" for everyone.
3. **Phone: switch to Karim Amrani** (Vie Étudiante, level 1). Yasmine's request is in his inbox. Approve it.
4. **Laptop:** without touching anything, the request appears in Mehdi's inbox (level 2). Open it. Check the room's other bookings and the equipment, then **Valider la séance**.
5. **Phone: switch back to Yasmine.** The request is *Validée*, and her QR pass is ready.
6. **Show a refusal:** on the laptop, refuse another request. A reason is required, and Yasmine (or the club) sees it.
7. **Show the safeguards:** as Yasmine, there is no Validations tab at all. Even through the API, the server refuses (checked automatically by `e2e/live_demo.mjs`).
