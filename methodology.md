# HEV–ICE Trim Matching Methodology

## Purpose

This project estimates the sticker-price premium for a conventional hybrid-electric vehicle (HEV) relative to a gasoline vehicle with the same make, model, model year, body configuration, drive configuration, and equipment position. The unit of observation is an HEV trim paired with one conventional internal-combustion-engine (ICE) trim.

For each retained pair,

```text
raw_premium = HEV base MSRP − ICE base MSRP
```

The matching output keeps nominal model-year MSRPs. Inflation to 2026 dollars and all later analysis variables are created downstream in `R/build_analysis_sample.R`.

This is an MSRP comparison, not a transaction-price or ownership-cost estimate. It does not subtract tax credits, dealer discounts, fuel savings, maintenance, financing, or resale value. It also is not a universal engineering estimate of the cost of hybrid hardware. It describes the observed sticker gap among the equipment peers that can be constructed from the source data.

## Scope

The source is the Teoalida Year-Make-Model-Trim Basic Specs database, a licensed trim-level catalog of US vehicles (August 2026 snapshot). The license does not allow redistribution, so this repository contains only the matched pairs in `data/matched.csv`, not the catalog or the code that reads it. The matching sample begins in model year 2012 and includes conventional HEVs only. Plug-in hybrids are outside this pipeline.

The 53 in-scope nameplates are:

- BMW: 3 Series, 5 Series, 7 Series.
- Acura: MDX, ILX.
- Audi: Q5.
- Lexus: ES, LS, LX, NX, RX.
- Mercedes-Benz: E-Class.
- Subaru: Crosstrek, Forester.
- Lincoln: MKZ.
- Mazda: CX-50.
- Ford: Fusion, Explorer, Escape.
- Hyundai: Sonata, Tucson, Elantra, Santa Fe, Palisade.
- Kia: Optima, Sorento, Sportage, Carnival.
- Toyota: 4Runner, Avalon, Camry, Corolla, Corolla Cross, Grand Highlander, Highlander, RAV4, Tacoma, Tundra.
- Honda: CR-V, Civic, Accord.
- INFINITI: QX60, Q70, Q50.
- GMC: Yukon.
- Cadillac: Escalade.
- Nissan: Rogue, Pathfinder, Murano.
- Chevrolet: Malibu.
- Porsche: Cayenne.
- Volkswagen: Touareg, Jetta.

Nameplates not listed above are not considered by this pipeline. Their omission is a scope decision rather than evidence that no defensible match exists.

## Powertrain definitions

The source engine classifications are reduced to two analysis categories:

- `gas`, `flex-fuel (FFV)`, and `mild hybrid` become `ice`.
- `hybrid` becomes `hev`.
- Other engine types, including plug-in hybrids, are excluded.

Flex-fuel vehicles are conventional comparison vehicles for this purpose. Mild hybrids are also treated as the conventional baseline because their small assist systems are part of the ordinary ICE ladder in many recent lineups.

The Acura ILX is the one exception to the source taxonomy. Teoalida calls the 2013–2014 ILX Hybrid a mild hybrid, but its Honda IMA motor assists propulsion. Those rows are therefore coded as `hev`.

Rows without a positive base MSRP are removed.

## Vehicle preparation

Preparation is shared across all makes. Matching rules do not reparse the source data.

### Model and trim parsing

Powertrain words such as `Hybrid`, `HEV`, `PHEV`, `Prime`, `Energi`, `Recharge`, `4xe`, `Plug-In`, and `Electric` are removed from normalized model and trim fields. Punctuation and case are then reduced to stable lowercase keys.

A blank or zero-valued `Trim` is recovered from the leading text in `Trim (description)` when possible. If a `Trim` field contains a pasted body/engine description, that suffix is removed. A trim that becomes empty after normalization receives the key `basic`.

The parenthetical engine description, package text introduced by `w/`, production-end date, body type, drive type, transmission, cylinders, displacement, horsepower, curb weight, combined MPG, door count, and pickup bed length are parsed into separate fields.

Transmission descriptions are reduced to `cvt`, `automatic`, `manual`, `automated_manual`, or a normalized fallback.

### Drive, body, package, and configuration keys

`all wheel drive` and `four wheel drive` share the matching key `awd_4wd`. Front-wheel drive and rear-wheel drive remain separate. Pooling AWD and 4WD means that they occupy the same equipment-comparison category; it does not claim that their transfer cases or driveline hardware are identical.

Body type and package descriptions receive whitespace, punctuation, and case normalization. Packages remain part of the exact join unless an HEV remap changes the package key.

Pickup bed length is parsed from the trim description and kept in the join. This prevents short-bed and long-bed Tacoma rows from being treated as interchangeable.

Leading three-digit manufacturer designations, including suffixes such as `h`, `t`, `i`, and `Li`, are parsed as badges. Lexus trim keys are additionally stripped of their leading badge so that, for example, `300h Luxury` and `350 Luxury` share the equipment key `luxury` while retaining the distinct badges `300h` and `350`.

RX long-wheelbase descriptions are marked `long`; all other RX rows are marked `standard`. The RX `L` suffix is represented by this configuration rather than the badge field, and the configuration is appended to the RX badge matching key so an RX L does not join a standard-wheelbase RX.

### Emissions labels and duplicates

PZEV, SULEV, and ULEV labels are removed from normalized trim names. Rows carrying those labels are dropped for most makes because they duplicate ordinary listings.

Subaru and BMW are exceptions. Some Subaru gas lineups and the 2017 BMW 330i comparison row appear only under an emissions-badge listing, so those makes retain the rows while still stripping the badge from the trim key.

Full-model-year rows are preferred to duplicate `Prod. End` listings. If only production-end rows exist, the latest cutoff is retained. Deduplication holds fixed year, make, model, normalized trim, powertrain, drive, body, package, doors, bed length, transmission, engine, horsepower, and MPG.

### Catalog corrections

The following corrections are made before matching:

- Honda Insight is recoded as Civic for 2019–2021.
- INFINITI M is recoded as Q70.
- Subaru XV Crosstrek is recoded as Crosstrek.
- BMW ActiveHybrid 5 is recoded as 5 Series and its trim is set to `ActiveHybrid 5`.
- BMW ActiveHybrid 7 is recoded as 7 Series for 2013–2015.
- Mercedes-Benz `E 400` spacing is normalized to `E400`.
- The leading `2.0i` engine badge is removed from Crosstrek trim keys.
- TFSI engine badges are removed from Audi package keys.
- EcoBoost engine badges are removed from Ford and Lincoln package keys.
- ICE-side `E 350` spacing is normalized for the E-Class matching key without changing the displayed source trim.
- Missing 2017 Lincoln MKZ Hybrid horsepower is filled with 188.
- The 2026 Subaru Forester gas MSRPs are replaced with the official stickers: Premium $31,995, Sport $34,795, Limited $35,995, and Touring $39,995. Source: [Subaru 2026 Forester pricing](https://media.subaru.com/newsrelease.do?id=2421).

Missing curb weights used in the matched sample are supplemented through `data/curb-weight-corrections.csv`, where each row is identified by model year, make, model, trim, and side (`hev` or `ice`). The correction file records the value, source URL and tier, quoted evidence, and whether the value is exact or shared across a mechanically identical configuration. Configuration propagation requires the same model year, powertrain/engine, drivetrain, body/wheelbase, and truck cab/bed where applicable; equipment-only trims may share a value when the cited source reports one weight for that configuration. The raw vendor CSV is unchanged. Of 98 matched source records investigated, 81 receive sourced weights and 17 remain unresolved rather than being guessed; unresolved weights are blank in `data/matched.csv`.

Matching rationales and citations are documented in the brand and model sections below. The complete rule tables are listed under [Manual renamings and rule tables](#manual-renamings-and-rule-tables).

## Matching framework

### Normal, mixed, and explicit nameplates

Each scoped nameplate has one matching mode after exclusions are applied:

- `normal`: every eligible HEV receives the ordinary exact-match keys, and the nameplate has no HEV allow or remap rules.
- `mixed`: every eligible HEV receives the ordinary exact-match keys, but selected HEVs receive declared remaps.
- `explicit`: an HEV is eligible only if it matches an allow or remap row. This is used where only selected years, trims, badges, or packages have defensible peers.

The mixed nameplates are Subaru Crosstrek, Lincoln MKZ, Toyota Corolla Cross, Honda CR-V, and Honda Accord.

The explicit nameplates are BMW 3 Series, 5 Series, and 7 Series; Acura MDX and ILX; Audi Q5; Lexus ES, LS, LX, NX, and RX; Mercedes-Benz E-Class; Mazda CX-50; Hyundai Sonata; Kia Optima; INFINITI QX60, Q70, and Q50; GMC Yukon; Cadillac Escalade; Chevrolet Malibu; Porsche Cayenne; and Volkswagen Touareg and Jetta.

All other scoped nameplates use normal matching. Exclusions and post-join ICE candidate preferences are separate from the matching mode.

Normal and mixed default matching can extend automatically when the source gains a later model year. Rule years are optional: a missing lower or upper endpoint is unbounded within the prepared data. Years are stated only when the mapping or eligibility policy changes over time.

### Default exact-match keys

The exact join uses:

```text
year
+ make
+ match_model
+ normalized body type
+ drive key
+ match trim
+ match badge
+ match package
+ bed length
```

The default match fields are the prepared model, normalized trim key, parsed badge, and normalized package. An HEV allow row admits an explicit HEV without changing those fields. An HEV remap row admits the HEV and replaces trim, badge, or package as declared. ICE rows always retain prepared values.

This structure distinguishes three matching cases:

1. General exact matching for nameplates whose HEV and ICE grades use the same names.
2. Mixed matching for lineups that combine exact names with selected grade remaps.
3. Explicit allowlists and semantic mappings where only declared years, badges, or grades are eligible.

No similarity score or nearest-neighbor search is used.

### Exclusions

Toyota `Base` rows are removed from both sides in every year. The source snapshot contains no Toyota `basic` row, so no separate blank-trim exclusion is needed.

The following HEV rows are also excluded:

- BMW ActiveHybrid 5 in 2012–2013.
- Ford Escape Limited in 2012.
- Lexus RX F Sport Handling in 2021–2022.
- Nissan Rogue SL in 2019.

Other HEVs may fail to match because no allow or remap row admits them on an explicit nameplate, or because no ICE row has the full exact key. Unmatched HEVs are omitted silently; this pipeline does not write an orphan table.

### ICE candidate resolution

An exact key can occasionally identify more than one ICE source row. Candidate resolution occurs in two ordered steps:

1. If any non-manual ICE candidate exists, manual candidates are removed.
2. If a declared displacement candidate exists, it is selected:
   - INFINITI Q70: 3.7 L.
   - Ford Escape SEL: 1.5 L.
   - Honda Accord: 1.5 L.
   - Toyota Camry: 2.5 L.

These are soft preferences: if the preferred candidate does not exist, the candidate set is left unchanged.

With the current source snapshot, the raw exact join has 38 HEVs with two candidates. The non-manual preference resolves 9; the displacement declarations resolve the remaining 29. The final output therefore contains 715 pairs and zero ties.

## Brand and model decisions

### BMW

ActiveHybrid badges identify the hybrid powertrain rather than the equipment peer:

- ActiveHybrid 3 maps to 335i.
- ActiveHybrid 5 maps to 535i for 2014–2016.
- ActiveHybrid 7 maps to 740Li.

The 2012–2013 ActiveHybrid 5 is excluded. It bundled leather, navigation, and four-zone climate content that the contemporary base 535i lacked. Equipment was substantially aligned after the model's life-cycle update. Source: [BMW ActiveHybrid 5 release](https://www.press.bmwgroup.com/usa/article/detail/T0122070EN_US/the-bmw-activehybrid-5?language=en_US).

All three BMW nameplates are explicit. ActiveHybrid 7 is an identity admission because the prepared hybrid trim is already `740Li`; the rule limits eligibility without changing its key. No unruled BMW HEV falls through to default matching.

### Acura

#### MDX

The 2017–2020 hybrid trim `Sport SH-AWD` maps to gas `SH-AWD`, with the package held exact. Advance Package therefore matches Advance Package, and Technology Package matches Technology Package.

Acura describes the Sport Hybrid as an SH-AWD package ladder. The Technology version has some hybrid-specific finish details, but this policy keeps it when the source package aligns. Source: [Acura MDX Sport Hybrid release](https://global.honda/en/newsroom/worldnews/2017/c170316MDX-Sport-Hybrid.html).

#### ILX

The 2013–2014 ILX Hybrid is recoded from source `mild hybrid` to HEV.

Only Hybrid Technology is retained:

- 2013 `basic` with Technology Package maps to gas `Technology Package`; the package is moved into the trim key because the two source years encode the grade differently.
- 2014 `Technology Package` matches the same gas grade.

Hybrid Base is omitted. The 2013 Base comparison is relatively clean, but the 2014 gas Base gained leather, heated and power seats, 17-inch wheels, and active noise cancellation that the Hybrid Base did not receive. A consistent Base comparison across both years is therefore not used. Hybrid Technology is not mapped to Premium.

Sources: [2013 ILX pricing](https://hondanews.com/en-US/releases/release-b472227849fc46029c557a811264b4a8-all-new-2013-acura-ilx-on-sale-today-with-a-starting-price-of-25-900), [2013 ILX press kit](https://hondanews.com/en-US/releases/release-17040050707d4f50ae771efc1b2c0a6f-2013-ilx-introduction), and [Edmunds 2013 ILX](https://www.edmunds.com/acura/ilx/2013/).

### Audi Q5

The 2013–2016 `2.0T Prestige quattro` HEV maps to `3.0T Prestige quattro`.

The two vehicles occupy the same Prestige equipment tier, including navigation, Bang & Olufsen audio, side assist, and adaptive lighting. No gas 2.0T Prestige peer exists in these years; matching a lower Premium or Premium Plus would change equipment tier. The hybrid's turbocharged four-cylinder and the gas vehicle's supercharged V6 are treated as the powertrain comparison. The resulting negative sticker gap is retained.

Sources: [2013 Audi Q5 media kit](https://media.audiusa.com/assets/documents/original/1119-news-2013-audi-q5-media-kit.pdf) and [Edmunds 2013 Q5 review](https://www.edmunds.com/audi/q5/2013/review/).

TFSI text is removed from package keys before the join.

### Lexus

Lexus uses an explicit badge correspondence. The three-digit badge is separated from the equipment-grade name, and only declared hybrid-to-gas badge pairs are eligible.

#### ES

ES 300h maps to ES 350, with trim, body, drive, and package held exact. ES 250 is not used because it represents the AWD gas path rather than the corresponding FWD equipment peer.

The 2022 ES F Sport near-zero premium is retained as genuine grade parity. Source: [Lexus 2022 ES release](https://pressroom.lexus.com/lexus-es-family-returns-for-2022-with-updated-tech-safety-first-ever-300h-f-sport-grade/).

#### LS

LS 500h maps to LS 500 only for 2018–2020. LS 600h L has no declared peer, and later LS 500h rows are omitted because the available flagship configurations do not provide the same equipment comparison.

#### LX

LX 700h maps to LX 600 from 2025 onward. The vehicles are both four-wheel drive, and the grade remains exact after the badge is stripped.

F Sport Handling and Luxury have same-name peers. Overtrail and Ultra Luxury are hybrid-only in the source and therefore do not join; Premium is gas-only.

#### NX

The badge mappings are:

- NX 300h to NX 200t in 2015–2017.
- NX 300h to NX 300 in 2018–2021.
- NX 350h to NX 250 in 2022–2023.
- NX 350h Base and Premium to NX 250 in 2024–2025.
- NX 350h Luxury to NX 350 Luxury in 2024–2025 because the corresponding NX 250 Luxury is not sold.
- NX 350h to NX 350 for all declared grades in 2026, after the NX 250 leaves the lineup.

Trim, drive, body, and package remain exact after the badge mapping. Undeclared NX hybrid badges or grade combinations do not match.

Sources for the equipment ladder and F Sport/Luxury distinctions: [CarsDirect 2022 NX](https://www.carsdirect.com/lexus/nx/2022) and [2023 Lexus NX brochure](https://www.lexus.com/content/dam/lexus/documents/brochures/models/2023/MY23-Lexus-NX-NXh-Brochure.pdf).

#### RX

RX 450h maps to RX 350 only for 2018–2022. Earlier RX 450h rows are omitted because the hybrid bundled Premium, Navigation, and in some years Comfort content that was absent from the apparent same-name gas peer.

RX 350h maps to RX 350 from 2023 onward. RX 500h F Sport Performance is not declared and does not match.

RX F Sport Handling is excluded in 2021–2022 because no same-content ICE trim exists. RX and RX L wheelbases are kept separate through the configuration key.

UX remains outside scope because the hybrid is AWD while the available gas UX peer is FWD.

### Mercedes-Benz E-Class

Only rear-wheel-drive E-Class HEVs in 2013–2015 are eligible:

- 2013 E400 Hybrid maps to E350 Sport.
- 2014–2015 E400 Sport Hybrid maps to E350 Sport.

The E400 Hybrid uses the same V6 family and is represented as the Sport sedan, so E350 Sport—not Luxury—is the equipment peer. `E 400` and `E400`, and `E 350` and `E350`, are normalized for matching.

Sources: [Edmunds 2013 E-Class review](https://www.edmunds.com/mercedes-benz/e-class/2013/review/) and the [2013 E-Class brochure](https://cdn.dealereprocess.org/cdn/brochures/mercedesbenz/2013-eclass.pdf).

### Subaru

XV Crosstrek is recoded as Crosstrek, and a leading `2.0i` is removed from the trim key.

For 2014–2016, Hybrid Base or a blank/basic hybrid trim maps to gas Limited. Edmunds describes the Hybrid as carrying the 2.0i Limited features except leather, plus hybrid-specific equipment. Sources: [Edmunds 2014 XV Crosstrek](https://www.edmunds.com/subaru/xv-crosstrek/2014/review/) and the [2014 XV Crosstrek brochure](https://cdn.dealereprocess.org/cdn/brochures/subaru/2014-xvcrosstrek.pdf).

The 2026 Crosstrek and the Forester use normal same-grade matching. The 2026 Forester gas sticker corrections are described under preparation.

### Lincoln MKZ

A blank/basic MKZ Hybrid trim maps to gas Base. Other MKZ rows use normal matching.

Zero-dollar pairs are retained. Lincoln explicitly introduced the MKZ Hybrid at the same price as the conventional MKZ. Source: [Lincoln MKZ Hybrid pricing release](https://www.prnewswire.com/news-releases/lincoln-makes-history-with-pricing-for-americas-most-fuel-efficient-luxury-sedan---2011-mkz-hybrid-98985504.html).

EcoBoost is removed from package keys because it identifies the engine rather than an equipment package.

### Mazda CX-50

The hybrid grade names omit the gas engine prefix:

- Hybrid Preferred maps to gas `2.5 S Preferred`.
- Hybrid Premium maps to gas `2.5 S Premium`.

The target is the non-turbo 2.5 S equipment ladder. CX-50 is explicit: only Preferred and Premium are admitted, so other hybrid grades do not fall through to same-name matching.

### Ford

Fusion and Explorer use normal exact matching.

Escape also uses normal matching, except the 2012 Hybrid Limited is excluded because its content and premium do not provide the same comparison used for later Escapes. Sources for the early content ladders: [2010 Escape Hybrid brochure](https://www.allcarcentral.com/Ford_pdf/Ford_Escape-Hybrid_2010.pdf) and [2011 Escape brochure](https://cdn.dealereprocess.org/cdn/brochures/ford/2011-escape.pdf).

When an Escape SEL exact key produces multiple engines, the 1.5 L ICE candidate is selected. EcoBoost is removed from Ford package keys.

### Hyundai

Sonata is explicit: only Limited in 2020–2023 is eligible. Earlier same-name rows are omitted because aspiration and equipment combinations do not provide a stable exact peer.

Tucson, Elantra, Santa Fe, and Palisade use normal exact matching.

Negative Santa Fe Limited hybrid premiums are retained when the equipment keys align. Hyundai's 2022 price sheet lists Limited Hybrid AWD at $40,710 and Limited gas AWD at $41,110. Source: [2022 Santa Fe price sheet](https://www.hyundainews.com/assets/documents/original/50107-2022MYSantaFePriceSheet20May2022.pdf).

### Kia

Optima is explicit: only EX in 2019–2020 is eligible.

Earlier Optima HEV EX rows are omitted because navigation, ventilated seating, and premium audio content cannot be recreated exactly on the gas EX without adding packages that also contain other equipment. Sources: [2017 Optima PHEV features](https://www.kiamedia.com/us/en/models/optima-phev/2017/features) and [2017 gas Optima features](https://www.kiamedia.com/us/en/models/optima/2017/features).

Sorento, Sportage, and Carnival use normal exact matching.

### Toyota

The scoped models are 4Runner, Avalon, Camry, Corolla, Corolla Cross, Grand Highlander, Highlander, RAV4, Tacoma, and Tundra.

All normally match on the exact prepared keys, subject to three rules:

1. `Base` Toyota rows are excluded from both sides in every year.
2. Corolla Cross S, SE, and XSE map to gas L, LE, and XLE respectively. These are the hybrid and gas names for the corresponding equipment grades.
3. Tacoma must have the same parsed bed length.

If Camry has more than one ICE engine candidate at the same equipment key, 2.5 L is selected.

Early Highlander Hybrid Limited premiums are retained as published same-grade pricing. Source: [Toyota 2011 Highlander pricing](https://pressroom.toyota.com/toyota-announces-pricing-for-new-2011-highlander-highlander-hybrid-and-pricing-adjustment-for-2011-prius-venza-and-fj-cruiser/).

### Honda

#### CR-V

CR-V uses normal matching through 2023. From 2024 onward:

- Hybrid Sport maps to gas EX.
- Hybrid Sport-L maps to gas EX-L.

Sport Touring has no declared remap. It does not join when there is no same-name gas peer. The grade includes Bose audio, navigation, 19-inch wheels, and a hands-free liftgate beyond the EX-L comparison. Source: [Honda CR-V feature guide](https://www.hondainfocenter.com/2024/cr-v/feature-guide/specifications/).

#### Civic

Civic uses normal exact matching. The 2019–2021 Insight is recoded as Civic before matching because the third-generation Insight occupies the Civic Hybrid product and trim position in the source catalog.

#### Accord

Accord uses normal matching with two grade mappings:

- Base maps to LX for 2018–2022.
- Touring maps to Touring V-6 for 2014–2017.

The Touring mapping keeps the equipment tier rather than forcing the hybrid onto a lower four-cylinder gas trim. When several exact Accord ICE candidates remain, 1.5 L is selected under the current engine preference.

Negative same-trim Touring HEV premiums are retained as actual pricing. Source: [2020 Accord Hybrid pricing release](https://www.prnewswire.com/news-releases/2020-honda-accord-hybrid-achieves-epa-rated-48-mpg-city-and-best-in-class-horsepower-on-sale-tomorrow-300925912.html).

### INFINITI

INFINITI M is recoded as Q70.

QX60 is explicit: blank/basic maps to Base only in 2014–2015. The 2016–2017 HEVs remain outside the declared window and do not fall through to default matching.

Q70 rules are:

- M35h maps to M37 in 2012–2013.
- Blank/basic maps to Base in 2014–2017.
- Luxe maps to 3.7 Luxe in 2018.
- If several ICE engines remain, select 3.7 L.

Q70 is explicit: only the listed year and grade mappings are admitted.

Q50 is explicit: Premium and Sport are eligible only in 2014–2015. Later or differently named Q50 hybrid rows are not admitted.

The Q50 Hybrid has equipment caveats, including Direct Adaptive Steering in the Deluxe Touring package, but the current policy retains the same-name Premium and Sport comparisons. Source: [2014 Q50 press kit](https://usa.infinitinews.com/en-US/releases/us-2014-infiniti-q50-press-kit).

### GMC Yukon

Only Yukon Hybrid Denali is eligible. It matches the conventional FFV Denali after AWD and 4WD are pooled in the drive key. Base Hybrid is not admitted.

The pooling is an equipment-tier comparison, not a claim that the gas AWD and hybrid 4WD systems are mechanically identical.

### Cadillac Escalade

Only Escalade Hybrid Platinum Edition is eligible. It matches the conventional FFV Platinum Edition with body configuration and pooled AWD/4WD held fixed.

Hybrid Base is not admitted because it bundles Premium Collection and rear-entertainment content absent from conventional Base. The Hybrid Platinum carries the full Platinum feature set. Source: [2011 Escalade brochure](https://www.auto-brochures.com/makes/Cadillac/Escalade/Cadillac_US%20Escalade_2011.pdf).

### Nissan

Rogue, Pathfinder, and Murano normally use same-grade exact matching.

The 2019 Rogue SL Hybrid is excluded. Gas SL gained standard ProPILOT Assist that the hybrid did not receive, so the very small apparent sticker gap does not represent equal equipment. Source: [2019 Rogue press kit](https://usa.nissannews.com/en-US/releases/us-2019-nissan-rogue-press-kit).

Pathfinder Hybrid and Murano Hybrid same-grade premiums are supported by Nissan pricing materials. Sources: [2014 Pathfinder Hybrid pricing](https://usa.nissannews.com/en-US/releases/nissan-announces-2014-pathfinder-hybrid-u-s-pricing) and [2016 Murano press kit](https://usa.nissannews.com/en-US/releases/us-2016-nissan-murano-press-kit).

### Chevrolet Malibu

A blank/basic Malibu Hybrid trim maps to gas LT. Malibu is explicit, so only the declared mapping is admitted. GM brochures describe the Hybrid as adding to or replacing LT features, making LT the equipment reference.

Sources: [2016 Malibu brochure](https://xr793.com/wp-content/uploads/2017/07/2016-Chevrolet-Malibu.pdf) and [2019 Malibu brochure](https://www.auto-brochures.com/makes/Chevrolet/Malibu/Chevrolet_US%20Malibu_2019.pdf).

### Porsche Cayenne

Cayenne is explicit. The normalized S Hybrid trim matches gas S only for 2012–2014. No later Cayenne HEV is admitted automatically.

### Volkswagen

#### Touareg

Touareg is explicit. Its Hybrid occupies an Executive-equivalent equipment position:

- 2012–2013 Hybrid maps to VR6 Executive.
- 2014 Hybrid maps to V6 Executive.
- 2015 V6 Hybrid maps to V6 Executive.

The target is a gasoline Executive, not a diesel TDI Executive.

Sources: [Edmunds 2013 Touareg review](https://www.edmunds.com/volkswagen/touareg/2013/review/) and [The Car Connection 2013 Touareg overview](https://www.thecarconnection.com/overview/volkswagen_touareg_2013).

#### Jetta

Jetta is explicit and has two eligible HEV rows:

- 2013 Hybrid SEL maps to gas SEL with Navigation.
- 2014 Hybrid SEL maps to gas SEL; navigation is standard.

Base and SE are omitted because keyless access and sunroof content move in opposite directions across the hybrid and gas package ladders. SEL Premium is omitted because of Bi-Xenon/AFS, Fender audio, and wheel content. The residual Fender audio on the 2013 gas SEL is accepted as part of the indivisible Navigation bundle.

If two SEL rows differ only by transmission after the exact join, the non-manual candidate is selected.

Sources: [2013 Jetta Hybrid pricing](https://www.autoblog.com/2012/10/04/2013-volkswagen-jetta-hybrid-priced-from-24-995/), [2013 Jetta brochure](https://www.auto-brochures.com/makes/Volkswagen/Jetta/VW_US%20Jetta_2013.pdf), and [2014 Jetta Hybrid release](https://media.vw.com/assets/documents/original/7319-20145+Jetta+Hybrid+Release.pdf).

## Manual renamings and rule tables

This section lists every hand-coded rule applied during matching, in addition to the catalog corrections above. Trim, badge, and package values are the normalized matching keys: lowercase, with punctuation replaced by spaces (so `2.5 S Preferred` becomes `2 5 s preferred`). `basic` is the key given to a blank source trim. A blank cell means the field is not restricted (on the HEV side) or not changed (on the ICE side); `(none)` means an empty package.

### Model renamings

These are applied to both sides before matching:

| Source name | Renamed to | Years |
| --- | --- | --- |
| Honda Insight | Honda Civic | 2019–2021 |
| INFINITI M | INFINITI Q70 | all |
| Subaru XV Crosstrek | Subaru Crosstrek | all |
| BMW ActiveHybrid 5 | BMW 5 Series, trim `ActiveHybrid 5` | all |
| BMW ActiveHybrid 7 | BMW 7 Series | 2013–2015 |

### HEV trim, badge, and package renamings

Each row admits the matching HEV and replaces its trim, badge, or package key with the ICE value shown before the exact join. ICE rows keep their own keys.

| Make | Model | Years | HEV trim | HEV badge | HEV package | Drive | ICE trim | ICE badge | ICE package |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Acura | MDX | 2017–2020 | `sport sh awd` |  |  |  | `sh awd` |  |  |
| Acura | ILX | 2013 | `basic` |  | `technology package` |  | `technology package` |  | (none) |
| Mercedes-Benz | E-Class | 2013 | `e400` |  |  | rear-wheel drive | `e350 sport` |  |  |
| Mercedes-Benz | E-Class | 2014–2015 | `e400 sport` |  |  | rear-wheel drive | `e350 sport` |  |  |
| BMW | 3 Series | all | `activehybrid 3` |  |  |  | `335i` | `335i` |  |
| BMW | 5 Series | 2014–2016 | `activehybrid 5` |  |  |  | `535i` | `535i` |  |
| Subaru | Crosstrek | 2014–2016 | `basic` |  |  |  | `limited` |  |  |
| Mazda | CX-50 | all | `preferred` |  |  |  | `2 5 s preferred` |  |  |
| Mazda | CX-50 | all | `premium` |  |  |  | `2 5 s premium` |  |  |
| Toyota | Corolla Cross | all | `s` |  |  |  | `l` |  |  |
| Toyota | Corolla Cross | all | `se` |  |  |  | `le` |  |  |
| Toyota | Corolla Cross | all | `xse` |  |  |  | `xle` |  |  |
| Honda | CR-V | 2024 on | `sport` |  |  |  | `ex` |  |  |
| Honda | CR-V | 2024 on | `sport l` |  |  |  | `ex l` |  |  |
| Honda | Accord | 2018–2022 | `base` |  |  |  | `lx` |  |  |
| Honda | Accord | 2014–2017 | `touring` |  |  |  | `touring v 6` |  |  |
| INFINITI | QX60 | 2014–2015 | `basic` |  |  |  | `base` |  |  |
| INFINITI | Q70 | 2014–2017 | `basic` |  |  |  | `base` |  |  |
| INFINITI | Q70 | 2018 | `luxe` |  |  |  | `3 7 luxe` |  |  |
| INFINITI | Q70 | through 2013 | `m35h` |  |  |  | `m37` |  |  |
| Volkswagen | Touareg | through 2013 | `basic` |  |  |  | `vr6 executive` |  |  |
| Volkswagen | Touareg | 2014 | `basic` |  |  |  | `v6 executive` |  |  |
| Volkswagen | Touareg | 2015 | `v6` |  |  |  | `v6 executive` |  |  |
| Volkswagen | Jetta | 2013 | `sel` |  |  |  |  |  | `navigation` |
| Lincoln | MKZ | all | `basic` |  |  |  | `base` |  |  |
| Chevrolet | Malibu | all | `basic` |  |  |  | `lt` |  |  |
| Audi | Q5 | 2013–2016 | `2 0t prestige quattro` |  |  |  | `3 0t prestige quattro` |  |  |
| Lexus | ES | all |  | `300h` |  |  |  | `350` |  |
| Lexus | LS | 2018–2020 |  | `500h` |  |  |  | `500` |  |
| Lexus | LX | 2025 on |  | `700h` |  |  |  | `600` |  |
| Lexus | NX | 2015–2017 |  | `300h` |  |  |  | `200t` |  |
| Lexus | NX | 2018–2021 |  | `300h` |  |  |  | `300` |  |
| Lexus | NX | 2022–2023 |  | `350h` |  |  |  | `250` |  |
| Lexus | NX | 2024–2025 | `base` | `350h` |  |  |  | `250` |  |
| Lexus | NX | 2024–2025 | `premium` | `350h` |  |  |  | `250` |  |
| Lexus | NX | 2024–2025 | `luxury` | `350h` |  |  |  | `350` |  |
| Lexus | NX | 2026 |  | `350h` |  |  |  | `350` |  |
| Lexus | RX | 2018–2022 |  | `450h` |  |  |  | `350` |  |
| Lexus | RX | 2023 on |  | `350h` |  |  |  | `350` |  |

### HEV admissions without renaming

On explicit nameplates, these HEVs are admitted with their own keys unchanged:

| Make | Model | Years | HEV trim | HEV package |
| --- | --- | --- | --- | --- |
| Acura | ILX | 2014 | `technology package` | (none) |
| BMW | 7 Series | all | `740li` |  |
| Hyundai | Sonata | 2020–2023 | `limited` |  |
| Kia | Optima | 2019–2020 | `ex` |  |
| INFINITI | Q50 | 2014–2015 | `premium` |  |
| INFINITI | Q50 | 2014–2015 | `sport` |  |
| GMC | Yukon | all | `denali` |  |
| Cadillac | Escalade | all | `platinum edition` |  |
| Volkswagen | Jetta | 2014 | `sel` |  |
| Porsche | Cayenne | through 2014 | `s` |  |

### Exclusions

| Side | Make | Model | Years | Trim |
| --- | --- | --- | --- | --- |
| HEV and ICE | Toyota | all | all | `base` |
| HEV | Nissan | Rogue | 2019 | `sl` |
| HEV | Lexus | RX | 2021–2022 | `f sport handling` |
| HEV | BMW | 5 Series | through 2013 | `activehybrid 5` |
| HEV | Ford | Escape | 2012 | `limited` |

### ICE candidate preferences

| Make | Model | Trim | Preferred displacement (L) |
| --- | --- | --- | --- |
| INFINITI | Q70 | any | 3.7 |
| Ford | Escape | `sel` | 1.5 |
| Honda | Accord | any | 1.5 |
| Toyota | Camry | any | 2.5 |

## Output

The matching produced 715 HEV–ICE pairs from 715 distinct HEV catalog rows, covering 53 nameplates in model years 2012–2026, with zero unresolved ties. This repository publishes those pairs as `data/matched.csv`, limited to the fields used in the analysis:

- `pair_id`: sequential row identifier.
- `year`, `make`, `model`: model year and prepared nameplate (after the model renamings above).
- `trim_hyb`, `trim_ice`: source trim names for the HEV and its ICE match. Some pairs share both trim names and differ in body or drive configuration.
- `body_type_hyb`: HEV body type (the ICE body type is identical by construction).
- `msrp_hyb`, `msrp_ice`: base MSRP in nominal model-year dollars.
- `hp_hyb`, `hp_ice`: rated horsepower.
- `mpg_combined_hyb`, `mpg_combined_ice`: EPA combined fuel economy.
- `curb_weight_hyb`, `curb_weight_ice`: curb weight in pounds, including the sourced supplements in `data/curb-weight-corrections.csv`.

Missing values are blank CSV fields. Inflation to 2026 dollars and analysis variables are added by `R/build_analysis_sample.R`.
