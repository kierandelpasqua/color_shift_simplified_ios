# Photo sources (H-05)

The 12 photos in web catalog order (`photo=N` index). IDs and photographers come from the web's `src/App.tsx`.
Downloads go to `ColorShift/Resources/Photos/<id>.jpg` at about 2400px on the long side, from
`https://images.unsplash.com/<id>?fm=jpg&fit=max&w=2400&h=2400&q=85` (the same image the web loads at `w=1800&q=88`).
The web credits link to the photographer profile (`unsplash.com/@handle`); the photo page column is optional.

Review columns: **People** = recognizable person; **Marks** = visible brand, logo or artwork. Unsplash's license
covers app use, but it gives no model or property release, so flag anything that could be an issue.

Reviewed 2026-11-25 (owner decisions): both portraits (#4, #5) kept, as on the web; minor street signage in
#2/#3 accepted. Files downloaded at 2400px on the long side (`fit=max&w=2400&h=2400&q=85`), 6.6 MB in total.

| N | ID | Theme | Alt text | Photographer | Unsplash page | People | Marks | OK |
|---|---|---|---|---|---|---|---|---|
| 0 | `photo-1500964757637-c85e8a162699` | outdoors | Mountain ridges under a vivid pink and blue sky | [Simon Berger](https://unsplash.com/@simon_berger) | — | no | no | [x] |
| 1 | `photo-1615729947596-a598e5de0ab3` | outdoors | Green mountain ridge and yellow wildflowers | [Daniela Kokina](https://unsplash.com/@danielakokina) | — | no | no | [x] |
| 2 | `photo-1787012055240-859e0bd53875` | urban | Colorful apartment buildings in Hong Kong | [Zoshua Colah](https://unsplash.com/@zoshuacolah) | — | no | small shop signs (Chinese text) | [x] |
| 3 | `photo-1787015163482-2e06e9091258` | urban | Red van passing colorful residential buildings | [Zoshua Colah](https://unsplash.com/@zoshuacolah) | — | no | small shop signs; van license plate | [x] |
| 4 | `photo-1557053910-d9eadeed1c58` | people | Portrait in a vivid red shirt | [Olena Bohovyk](https://unsplash.com/@olenkasergienko) | — | yes | no | [x] |
| 5 | `photo-1617690032703-f991ed0e0ee6` | people | Portrait in pink and green with sunglasses | [Brian Lawson](https://unsplash.com/@visualartery) | — | yes | no | [x] |
| 6 | `photo-1534599864649-c66531e112eb` | animals | Iridescent green and blue bird feathers | [Alexander Sinn](https://unsplash.com/@swimstaralex) | — | no | no | [x] |
| 7 | `photo-1689758380989-f92c89619a2d` | animals | Green and yellow chameleon in close-up | [Rob Potter](https://unsplash.com/@robpotter) | — | no | no | [x] |
| 8 | `photo-1550859492-d5da9d8e45f3` | abstract | Soft rainbow color field | [Sean Sinclair](https://unsplash.com/@seanwsinclair) | — | no | no | [x] |
| 9 | `photo-1548746450-48dbc4747adc` | abstract | Flowing purple, red and warm orange shapes | [Marvin van Beek](https://unsplash.com/@marvinvanbeek) | — | no | no | [x] |
| 10 | `photo-1760445798933-4d3945d0b06b` | objects | Bowl of colorful objects and plants | [Runda Choo](https://unsplash.com/@rundachoo) | — | no | no | [x] |
| 11 | `photo-1558769673-de478227d1f5` | objects | Headset, scissors and teapot arranged on a table | [Alex Gruber](https://unsplash.com/@alex_gruber) | — | no | no | [x] |

Credit links in the app add `?utm_source=color_shift&utm_medium=referral` (Unsplash API guidelines; T-014).
