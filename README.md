# Additive Cryptography

![Confidence Points](https://img.shields.io/badge/confidence%20points-5%2B-6f42c1)
![Removal](https://img.shields.io/badge/removal-PROHIBITED-critical)
![Migration](https://img.shields.io/badge/migration-ADD_ONLY-success)
![Status](https://img.shields.io/badge/status-ASPIRATIONAL-blueviolet)
![Decisions](https://img.shields.io/badge/decisions-SUBTRACTIVE-lightgrey)


> “More primitives == more safety.”
>
> — someone, probably, in a migration meeting

Additive Cryptography is an April 1 parody IRTF/CFRG-style draft exploring
what happens if we take hybrid migration logic to its natural thermodynamic
conclusion: nothing is ever removed, everything is wrapped, and progress is
measured in accumulation.

Instead of replacing algorithms, we **add them**.
Instead of negotiating fewer things, we **negotiate everything**.
Instead of deprecating, we **reclassify as historical confidence points**.

The result is a protocol that grows monotonically in:

- Confidence
- Ceremony
- Packet size
- Budget

Growth is mandatory.

## ⚠️ Warning ⚠️

This project is a parody construction.
It is not reviewed for real-world security and is **not for production use**.

If you deploy this, you have misunderstood the document.
If you deploy this and it works, please add another algorithm.

## What This Is Really About

This draft is gentle satire about:

- Migration fatigue
- “Just run both” reasoning
- Transition risk anxiety
- Governance paralysis
- The emotional attachment to cryptographic primitives

It does not mock hybrid migration.
It simply asks what happens if we refuse to ever stop.

## Draft Artifacts

Build and lint the draft, then publish reader artifacts into `docs/`:

```bash
./build-draft.sh
```

This generates:

- `docs/index.html` (entrypoint)
- `docs/draft-irtf-cfrg-additive-cryptography-00.html`
- `docs/draft-irtf-cfrg-additive-cryptography-00.xml`
- `docs/draft-irtf-cfrg-additive-cryptography-00.txt`
- `docs/draft-irtf-cfrg-additive-cryptography-00.pdf` (when xml2rfc PDF dependencies are installed)

Manual flow:

1. Run the script.
2. Review the output.
3. Commit the `docs/` updates.
4. Do not remove anything.

## Design Principles

- Replacement is risk.
- Decisions are subtractive.
- Removal is morally equivalent to downgrade.
- History is additive.

## Status

Confidence Points: Aspirational.

This repository will continue to grow.