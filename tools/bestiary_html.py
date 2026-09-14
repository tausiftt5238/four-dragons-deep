import json, html, re, io, sys

SRC = "/tmp/claude-1000/-home-ttausif-game-project-first-person-dungeon-crawler/30c2fcae-cc3a-4bc2-bd80-fd3c4418a61c/scratchpad/bestiary.json"
OLD = "docs/bestiary.html"
DST = "docs/bestiary.html"

d = json.load(open(SRC))
old = open(OLD).read()
style = old[old.index("<style>"): old.index("</style>") + len("</style>")]

# Two new classes: the element badge in Attacks, and the skill chip.
style = style.replace("  .gaps {", """  .elem {
    display: inline-block; font-family: "IBM Plex Mono", ui-monospace, monospace;
    font-size: 10px; font-weight: 600; letter-spacing: .06em; text-transform: uppercase;
    padding: 2px 6px; border-radius: 2px; margin-right: 5px;
    color: var(--wire); background: var(--res-bg); white-space: nowrap;
  }
  .elem-phys { color: var(--ink-3); background: var(--null-bg); }
  .ail { white-space: nowrap; }
  .ail b { color: var(--weak); font-weight: 600; }
  .skill { white-space: nowrap; }
  .skill b { color: var(--ink); font-weight: 600; }
  .skill .fx { display: block; font-size: 12px; color: var(--ink-3); }
  .skill .mp {
    font-family: "IBM Plex Mono", ui-monospace, monospace;
    font-size: 10.5px; color: var(--ink-3);
  }
  .dash { color: var(--ink-3); }

  .legend {
    display: grid; gap: 1px; margin-top: 12px;
    grid-template-columns: repeat(auto-fit, minmax(268px, 1fr));
    background: var(--rule); border: 1px solid var(--rule);
  }
  .legend-cell { background: var(--panel); padding: 12px 14px 14px; }
  .legend-cell b {
    font-family: "Archivo", sans-serif; font-size: 14.5px; color: var(--ink);
    display: block; margin-bottom: 2px;
  }
  .legend-cell .fx { font-size: 13px; color: var(--ink-2); display: block; }
  .legend-cell .who {
    display: block; margin-top: 6px; font-size: 12px; color: var(--ink-3);
    font-family: "IBM Plex Mono", ui-monospace, monospace; line-height: 1.45;
  }
  .legend-cell .mp {
    float: right; font-family: "IBM Plex Mono", ui-monospace, monospace;
    font-size: 10.5px; color: var(--wire);
  }

  .gaps {""", 1)

ELEMENTS = ["phys", "fire", "ice", "thunder", "light", "dark"]
EL_HEAD  = {"phys": "Phys", "fire": "Fire", "ice": "Ice",
            "thunder": "Thdr", "light": "Light", "dark": "Dark"}
EL_NAME  = {"phys": "Blade", "fire": "Fire", "ice": "Ice",
            "thunder": "Thunder", "light": "Light", "dark": "Dark"}
STATE = {"weak": ("a-weak", "Weak"), "resist": ("a-resist", "Res"),
         "null": ("a-null", "Null"), "repel": ("a-repel", "Rep"),
         "drain": ("a-drain", "Drain"), "": ("a-none", "&middot;")}
AIL = {"poison": "Poison", "paralyzed": "Paralysis", "silence": "Silence",
       "immobilize": "Bind"}
TALK = {"cowardly": "Survival", "greedy": "Gain", "proud": "Logic",
        "lonely": "Flatter"}
STAT = {"atk": "ATK", "def": "DEF", "mag": "MAG", "agl": "AGL"}


def chart_cell(chart):
    out = []
    for e in ELEMENTS:
        cls, label = STATE[chart.get(e, "")]
        out.append('<span class="a %s" title="%s %s">%s</span>'
                   % (cls, EL_HEAD[e], label.replace("&middot;", "&middot;"), label))
    return '<td class="chart">%s</td>' % "".join(out)


def attacks_cell(r):
    el = r["attack_element"] or "phys"
    cls = "elem elem-phys" if el == "phys" else "elem"
    return '<td><span class="%s">%s</span></td>' % (cls, EL_NAME[el])


def ailment_cell(r):
    """The ailment is a spell now: its own turn, its own MP, its own odds."""
    if not r["status_attack"] or not r["ail_spell"]:
        return '<td><span class="dash">&mdash;</span></td>'
    what = AIL.get(r["status_attack"], r["status_attack"].title())
    # Bind's spell and its status share a name; saying it twice reads as a bug.
    fx = "%d&#37; to land" % r["ail_land"] if what == r["ail_spell"] \
        else "%s &middot; %d&#37; to land" % (what, r["ail_land"])
    return ('<td><span class="skill"><b>%s</b> <span class="mp">%d mp</span>'
            '<span class="fx">%s</span></span></td>'
            % (r["ail_spell"], r["ail_mp"], fx))


def skill_effect(r):
    """What the skill does, said from the player's side of the screen."""
    if r["support_type"] == "dispel":
        if r["support_clears"] == "buffs":
            return "strips everything you have raised"
        return "clears its own side's penalties"
    stat = STAT.get(r["support_stat"], r["support_stat"].upper())
    own = r["support_scope"] == "party"
    if own:
        return "raises its side's %s" % stat if r["support_delta"] > 0 \
            else "lowers its side's %s" % stat
    return "raises your %s" % stat if r["support_delta"] > 0 else "lowers your %s" % stat


def skill_cell(r):
    if not r["support"]:
        return '<td><span class="dash">&mdash;</span></td>'
    return ('<td><span class="skill"><b>%s</b> <span class="mp">%d mp</span>'
            '<span class="fx">%s</span></span></td>'
            % (r["support_name"], r["support_mp"], skill_effect(r)))


def talk_cell(r):
    if not r["negotiable"]:
        return '<td><span class="no">will not talk</span></td>'
    return '<td class="n">%s &middot; diff %d</td>' % (
        TALK.get(r["personality"], r["personality"].title() or "Any"),
        r["talk_difficulty"])


def rng(lo, hi):
    return str(lo) if lo == hi else "%d&ndash;%d" % (lo, hi)


HEAD = ('<thead><tr><th scope="col">Name</th><th scope="col">Var</th>'
        '<th scope="col">Level</th><th scope="col">HP</th><th scope="col">Exp</th>'
        '<th scope="col">Phys &nbsp; Fire &nbsp; Ice &nbsp; Thdr &nbsp; Light &nbsp; Dark</th>'
        '<th scope="col">Attacks with</th><th scope="col">Ailment</th>'
        '<th scope="col">Skill</th>'
        '<th scope="col">Talk</th></tr></thead>')


def row(r, var_col=None):
    name = html.escape(r["name"])
    if r["needs_art"]:
        name += ' <span class="needs">needs art</span>'
    if var_col is None:
        var_col = '<span class="rank">%s</span>' % ("B" if r["rank"] else "A")
    icons = ""
    if r["icons"] > 1:
        icons = ' <span class="rank">%d icons</span>' % r["icons"]
    return ("<tr><th scope=\"row\">%s</th><td class=\"n\">%s</td>"
            "<td class=\"n\">%s%s</td><td class=\"n\">%s</td><td class=\"n\">%s</td>%s%s%s%s%s</tr>"
            % (name, var_col,
               rng(r["lv_lo"], r["lv_hi"]), icons,
               rng(r["hp_lo"], r["hp_hi"]), rng(r["exp_lo"], r["exp_hi"]),
               chart_cell(r["chart"]), attacks_cell(r), ailment_cell(r),
               skill_cell(r), talk_cell(r)))


def table(rows, var_cols=None):
    body = "\n".join(row(r, None if var_cols is None else var_cols[i])
                     for i, r in enumerate(rows))
    return ('<div class="scroll"><table>%s<tbody>\n%s\n</tbody></table></div>'
            % (HEAD, body))


TIER_BLURB = {
 1: "Everything here answers to a blade or to Ember, and nothing nulls, repels or drains. "
    "All of them will talk.",
 2: "Levels roughly double. The skills are spread across all four stats, so no single "
    "counter answers the whole band.",
 3: "Six templates across five floors, so repetition begins here.",
 4: "Four templates across the last five floors &mdash; the thinnest band in the game. "
    "Both wizards carry a dispel, which is where a player who has not bought one finds "
    "out what they do.",
}


def tier_counts(rows):
    """Said out of the data rather than kept in a string that goes stale."""
    n = len(rows)
    el = sum(1 for r in rows if r["attack_element"])
    ail = sum(1 for r in rows if r["status_attack"])
    sk = sum(1 for r in rows if r["support"])
    return (" %d of the %d call up an element, %d throw an ailment, %d carry a skill."
            % (el, n, ail, sk))
ROMAN = {1: "I", 2: "II", 3: "III", 4: "IV"}

parts = []
for t in d["tiers"]:
    rows = t["rows"]
    lv_lo = min(r["lv_lo"] for r in rows)
    lv_hi = max(r["lv_hi"] for r in rows)
    parts.append("""
  <section class="tier">
    <div class="tier-head"><span class="tier-num">%s</span><h2>Tier %s</h2><span class="floors">floors %d&ndash;%d &middot; ordinary lv %d&ndash;%d &middot; boss lv %d</span></div>
    <p class="blurb">%s</p>
    %s
  </section>""" % (ROMAN[t["tier"]], ROMAN[t["tier"]], t["first"], t["last"],
                   lv_lo, lv_hi, t["boss_lv"],
                   TIER_BLURB[t["tier"]] + tier_counts(rows),
                   table(rows)))

wardens = d["wardens"]
w_vars = ['<span class="rank">%s</span>' % ", ".join(str(f) for f in w["floors"])
          for w in wardens]
parts.append("""
  <section class="tier">
    <div class="tier-head"><span class="tier-num">&#9733;</span><h2>Wardens</h2><span class="floors">one per maze floor &middot; never negotiable</span></div>
    <p class="blurb">The floor's locked door. It does not roam, it holds the key, and it opens with two icons. Five rotate across the sixteen maze floors &mdash; the Var column lists the floors each one actually lands on, and the level and HP ranges span the first of those to the last.</p>
    %s
  </section>""" % table(wardens, w_vars))

bosses = d["bosses"]
b_vars = ['<span class="rank">fl %d</span>' % b["floor"] for b in bosses]
parts.append("""
  <section class="tier">
    <div class="tier-head"><span class="tier-num">&#9733;</span><h2>Bosses</h2><span class="floors">floors 5, 10, 15, 20 &middot; level = floor &times; 2</span></div>
    <p class="blurb">One closes each tier. Every one nulls both banishing lines, so none of them can fall to a coin flip &mdash; and from floor ten on, two of the four answer a stacked party by stripping it.</p>
    %s
  </section>""" % table(bosses, b_vars))

# ── Skill legend ─────────────────────────────────────────────────────────────
carriers = {}
order = []
for group in ([r for t in d["tiers"] for r in t["rows"]] + wardens + bosses):
    k = group["support"]
    if not k:
        continue
    if k not in carriers:
        carriers[k] = {"spec": group, "who": []}
        order.append(k)
    carriers[k]["who"].append(group["name"])

legend = []
for k in order:
    spec = carriers[k]["spec"]
    who = carriers[k]["who"]
    legend.append(
        '<div class="legend-cell"><span class="mp">%d mp</span><b>%s</b>'
        '<span class="fx">%s</span><span class="who">%s</span></div>'
        % (spec["support_mp"], spec["support_name"], skill_effect(spec),
           " &middot; ".join(html.escape(n) for n in who)))

parts.append("""
  <section>
    <div class="tier-head"><span class="tier-num">&#9881;</span><h2>Every skill a demon casts</h2><span class="floors">%d skills &middot; %d of %d demons carry one</span></div>
    <p class="blurb">A demon reaches for its skill on roughly three turns in ten, and only while it still has the MP and somewhere for the stage to go. The two dispels are held back until there is actually something to take &mdash; a demon will not spend a phase stripping a side that has raised nothing.</p>
    <div class="legend">%s</div>
  </section>""" % (len(order), sum(len(v["who"]) for v in carriers.values()),
                   sum(len(t["rows"]) for t in d["tiers"]) + len(wardens) + len(bosses),
                   "".join(legend)))

total = sum(len(t["rows"]) for t in d["tiers"]) + len(wardens) + len(bosses)
with_skill = sum(len(v["who"]) for v in carriers.values())
with_ail = sum(1 for t in d["tiers"] for r in t["rows"] if r["status_attack"]) \
         + sum(1 for r in wardens + bosses if r["status_attack"])
with_elem = sum(1 for t in d["tiers"] for r in t["rows"] if r["attack_element"]) \
          + sum(1 for r in wardens + bosses if r["attack_element"])

page = """<title>Gauntlet Bestiary</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500;600&display=swap">
%s

<div class="wrap">

  <header class="masthead">
    <p class="eyebrow">Generated from Enemy.TEMPLATES &middot; %d entries &middot; 20 floors</p>
    <h1>Gauntlet Bestiary</h1>
    <p class="stand">Everything the run can put in front of you, what it swings, and what it casts. Level, HP and experience come off the floor rather than the row, so each entry shows the range it spans across the floors it appears on.</p>
  </header>

  <section>
    <div class="rules">
      <div class="rule-cell"><b>Ordinary</b><span>floor &times; 1.5</span><p>Plus one for the B variant of a pair.</p></div>
      <div class="rule-cell"><b>Warden</b><span>floor &times; 1.75</span><p>One per maze floor. Holds the key.</p></div>
      <div class="rule-cell"><b>Boss</b><span>floor &times; 2</span><p>Every fifth floor, in a corridor.</p></div>
      <div class="rule-cell"><b>Worth</b><span>10 + lv&sup2; / 2</span><p>Wardens pay double, bosses triple.</p></div>
    </div>
  </section>

  <section>
    <div class="tier-head"><span class="tier-num">&#9876;</span><h2>How a demon spends its turn</h2><span class="floors">read the Attacks and Skill columns together</span></div>
    <p class="blurb">A demon checks three things in order and swings if none of them fire. <b>Ailment</b> goes out first, three turns in ten, and only while someone standing is still clean &mdash; it can be thrown at anyone on your side, not just whoever it is hitting. <b>Skill</b> is next, also three in ten. <b>Attacks with</b> is the element it calls up, and it reaches for that <em>every</em> turn it can pay for one: MP is a magazine, not a dice roll, so a caster opens hard and finishes the fight with its hands. A banishing line is the exception, held back to one turn in five, because a demon it takes from you does not come back.</p>
    <p class="blurb">All three come out of the same pool, and a demon never spends its last MP on anything but its element. %d of the %d demons call up an element, %d throw an ailment, and %d carry a skill.</p>
  </section>
%s

  <section class="gaps">
    <h2>What the table says is missing</h2>
    <p><b>The tiers are lopsided.</b> Ten templates cover tier I and ten cover tier II, but only <strong>six</strong> cover tier III and <strong>four</strong> cover tier IV. The deepest five floors &mdash; the ones a player only reaches by earning them &mdash; have the least to show. Filling those two bands is worth more than anything else you could add.</p>
    <p><b>Every warden still needs a sprite.</b> All five are written with an art note and none is drawn. They are the most drawable things on the list &mdash; a gargoyle, a wight, a hound, a basilisk and a mimic all have unmistakable silhouettes &mdash; so they are the sensible place to start.</p>
    <p><b>Nothing past tier II carries a banishing line.</b> Light and dark stop being threats exactly where the run gets hard, so the deep floors are less varied than the shallow ones rather than more.</p>
    <p><b>Only four ailments exist, and two of them do the same job.</b> Bind and Paralysis both cost a demon its turn, so across thirty-nine entries the real variety is poison, silence and &ldquo;you do not act&rdquo;. Now that throwing one costs a demon its turn, that thinness shows more than it used to.</p>
  </section>

  <footer>Generated from the live tables &middot; ordinary lv = floor &times; 1.5 &middot; boss lv = floor &times; 2 &middot; skill odds 3 in 10</footer>

</div>
""" % (style, total, with_elem, total, with_ail, with_skill, "\n".join(parts))

open(DST, "w").write(page)
print("wrote %s  (%d entries, %d with a skill, %d with an element)"
      % (DST, total, with_skill, with_elem))
