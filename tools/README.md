# Regenerating the bestiary

`docs/bestiary.html` is generated, not hand-edited. Two steps, from the repo root:

```
~/apps/Godot_v4.6.2-stable_linux.x86_64 --headless --path . --script tools/bestiary_dump.gd
python3 tools/bestiary_html.py
```

The first builds every template at the first and last floor of its band and
writes the numbers to JSON; the second renders the page. Both read the live
tables, so a change to `Enemy.TEMPLATES` or `Spell.DATA` is one rerun away from
being on the page. The dump writes `.godot/bestiary.json` and the renderer reads
it from there — gitignored, and it survives between sessions.

The page's CSS is lifted from the previous `docs/bestiary.html` on each run, so
edit the style there and it survives the next regeneration.
