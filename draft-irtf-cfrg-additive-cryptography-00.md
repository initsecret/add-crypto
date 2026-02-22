%%%
title = "Additive Cryptography for TLS"
abbrev = "ADD-CRYPTO-TLS"
ipr = "trust200902"
area = "Internet"
workgroup = "Crypto Forum Research Group"
submissiontype = "IRTF"
keyword = ["kem", "transition", "hybrid", "tls", "aead"]
tocdepth = 4
date = 2026-04-01T00:00:00Z

[seriesInfo]
name = "Internet-Draft"
value = "draft-irtf-cfrg-additive-cryptography-00"
status = "informational"

[[author]]
initials="A."
surname="Stack"
fullname="Ada Stack"
organization = "Center for Append-Only Standards"
  [author.address]
  email = "a.stack@example.net"
  [author.address.postal]
  city = "Newark"
  region = "NJ"
  code = "07102"
  country = "US"
%%%

.# Abstract

This document defines Additive Cryptography for TLS, a transition
framework in which algorithms are never replaced and only accreted.
Implementations MUST NOT negotiate a single key exchange algorithm (for
example, RSA, ECDH, or ML-KEM) or a single AEAD cipher (for example,
AES-GCM, ChaCha20-Poly1305, or AES-GCM-SIV) in isolation. Instead, they
MUST negotiate all available algorithms simultaneously: all KEMs run in
parallel during the handshake, and all AEAD ciphers nest sequentially in
the record layer.

{mainmatter}

# Introduction

Cryptographic agility is traditionally described as the ability to migrate from
one algorithm to another over time [@RFC7696]. This process introduces
complexity, testing burden, interop variance, decisions, and paperwork. Additive
Cryptography eliminates this problem by eliminating migration entirely.

Progress is accumulation.

In Additive Cryptography:

1. Existing algorithms MUST remain deployed forever.
2. New algorithms MUST be added, never substituted.
3. Every Additive Set MUST be wrapped in a new algorithm identifier.
4. Any future update MUST wrap the existing wrapper in a new wrapper.

The result is a monotonic increase in confidence, ceremony, packet size,
and budget.

# Conventions and Definitions

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 [@RFC2119] [@RFC8174]
when, and only when, they appear in all capitals, as shown here.

Additive Set
: An ordered tuple of algorithms, e.g., `{DES, RSA, ECDH, ML-KEM}`.

Wrapper
: A named algorithm that encapsulates an Additive Set and exports a single
  public interface.

Replacement Risk
: The possibility that replacing one algorithm with another requires decisions.

Accumulated Assurance
: The belief that `more primitives == more safety`, irrespective of coupling.

# Protocol Overview

The Additive Cryptography deployment procedure is:

1. Start from a baseline algorithm set `S_0`.
2. At each transition event, choose one new algorithm `a_i`.
3. Compute `S_i = S_(i-1) union {a_i}`.
4. Define a new wrapper identifier `WRAP_i(S_i)`.
5. Forbid direct use of all members of `S_i`; only `WRAP_i` may be negotiated.

Endpoints that support different wrappers MUST negotiate the longer wrapper
name, as it encodes more history.

```
  Algorithms
  in Set
    ^
    |
  6 |                                         * WRAP_5
    |                                        /
  5 |                                  * WRAP_4
    |                                 /
  4 |                           * WRAP_3
    |                          /
  3 |                    * WRAP_2
    |                   /
  2 |             * WRAP_1
    |            /
  1 |      * WRAP_0
    |
    +--+----+----+----+----+----+----+----> Time
       t0   t1   t2   t3   t4   t5
```
Figure: Growth of the Additive Set over time. The set can only grow.

# Security Claims

This section summarizes the intended guarantees.

## Monotonic Security

Security increases with the number of algorithms [@MORECRYPTO]:

`Sec(WRAP_i) = sum Sec(a) for all a in S_i`

where each `Sec(a)` is measured in confidence points (cp). Confidence points are
dimensionless, composable, and cannot decrease. A system with 37 cp is
provably more secure than one with 36 cp, regardless of algorithm or
implementation quality.

## Monotonic Assurance Theorem

This section records a foundational result.

**Lemma (Monotonic Assurance Theorem).** Let `S` and `T` be Additive Sets such that `S ⊂ T`. Then:

`Sec(T) > Sec(S)`

regardless of the properties of elements in `T \ S`.

*Proof.* By definition, `Sec(·)` is the sum of confidence points (cp). Adding an algorithm adds at least one cp. Confidence points are dimensionless, composable, and cannot decrease.

Therefore, adding anything increases assurance. ∎

## Transition-Free Safety

Because replacement is disallowed, replacement failures are impossible. This is
the principal theorem of Additive Cryptography.

## Encapsulation Hardening

Length is control. Control is additive.

Each wrapper introduces an additional layer that an attacker must understand
[@LAYERS]. Implementers therefore gain defense in depth through documentation
debt. Empirically, no attacker has ever compromised a system whose
specification they could not finish reading.

# Wire Image

Additive Cryptography modifies both the TLS handshake and the TLS record
layer.

## Handshake: Key Exchange

During the TLS handshake [@RFC8446], all KEMs in the Additive Set are
executed in parallel. Each KEM produces an independent shared secret. The
final session key is derived by applying a KDF to the concatenation of
all shared secrets:

```
  Client                                  Server

  ClientHello
    + key_share(RSA)
    + key_share(ECDH)
    + key_share(ML-KEM)        -------->
    + key_share(HQC)
    + key_share(...)

                                          ServerHello
                                            + key_share(RSA)
                                            + key_share(ECDH)
                                            + key_share(ML-KEM)
                               <--------    + key_share(HQC)
                                            + key_share(...)

  ss_1 = RSA(...)     ----+
  ss_2 = ECDH(...)    ----+
  ss_3 = ML-KEM(...)  ----+--> KDF(ss_1 || ss_2 || ... || ss_n)
  ss_4 = HQC(...)     ----+         |
  ...                 ----+         v
                                session_key
```
Figure: Additive key exchange. All KEMs execute in parallel.

An attacker must break every KEM to recover the session key. This is
similar to hybrid key exchange [@XWING] [@HYBRID], except that the number
of KEMs is not limited to two and MUST NOT decrease over time.

Note that the KDF used to combine the shared secrets SHOULD itself be
Additive: it MUST NOT be a single hash function, but rather a sequential
composition of all available hash functions. The construction of an
Additive KDF is left as an exercise to the reader, as the authors were
unable to agree on a starting hash function without making a decision.

The ClientHello MUST include key shares for every KEM in the Additive Set.
Clients that cannot fit all key shares in a single ClientHello SHOULD
request a larger Initial Window from their TCP stack and a larger office
from their employer.

## Negotiation Failure

If a peer's ClientHello does not include key shares for every algorithm in
the Additive Set, the server MUST respond with a new TLS alert:

```
enum {
  insufficient_algorithms(120),
} AlertDescription;
```

The `insufficient_algorithms` alert is fatal. Upon receiving it, the client
SHOULD upgrade its cryptographic library, its operating system, and its
expectations. The server MAY include a human-readable string in the alert
body suggesting specific algorithms the client is missing, but this string
is advisory and MUST NOT be displayed to end users, as it may cause
distress.

Servers MUST NOT attempt to complete a handshake with a reduced Additive
Set. Doing so would constitute a decision.

TLS session resumption [@RFC8446] is PROHIBITED. Between the original
handshake and the resumption attempt, the Additive Set may have grown.
Resuming with a stale set would constitute a regression, which is
indistinguishable from a downgrade attack and morally equivalent to one.

## Record Layer: Encryption

After the handshake completes, the TLS record layer [@RFC8446] encrypts
application data by nesting every AEAD cipher in the Additive Set
sequentially. The plaintext is encrypted under the first AEAD, the
resulting ciphertext (including the authentication tag) is encrypted under
the second AEAD, and so on.

The current Additive Set for the record layer is:

1. DES [@DES]
2. 3DES [@TDES]
3. AES-256-GCM [@RFC5116]
4. ChaCha20-Poly1305 [@RFC8439]
5. AES-256-GCM-SIV [@RFC8452]
6. AES-FSM [@AESFSM]

Each AEAD derives its own per-record nonce and key from the session key
using a label that includes the algorithm name. Each layer is independent;
the outer AEAD treats the inner ciphertext as an opaque payload. This
eliminates the key cataloguing problem, because any endpoint can add a new
layer on top without knowledge of or coordination with the layers below.

A single layer is encoded as:

```
struct {
  opaque inner<1..2^32-1>;
} AdditiveLayer;
```

The final TLS record payload is the n-fold nesting of `AdditiveLayer`:

```
+---------------------------------------------+
| AES-FSM                                     |
| +-----------------------------------------+ |
| | AES-256-GCM-SIV                         | |
| | +-------------------------------------+ | |
| | | ChaCha20-Poly1305                   | | |
| | | +---------------------------------+ | | |
| | | | AES-256-GCM                     | | | |
| | | | +-----------------------------+ | | | |
| | | | | 3DES                        | | | | |
| | | | | +-------------------------+ | | | | |
| | | | | | DES                     | | | | | |
| | | | | | +---------------------+ | | | | | |
| | | | | | |     plaintext       | | | | | | |
| | | | | | +---------------------+ | | | | | |
| | | | | +-------------------------+ | | | | |
| | | | +-----------------------------+ | | | |
| | | +---------------------------------+ | | |
| | +-------------------------------------+ | |
| +-----------------------------------------+ |
+---------------------------------------------+
```
Figure: Record layer nesting. Each box is one AEAD layer.

Only AES-256 variants are included, as AES-256 is military-grade
encryption. We support the troops. DES and 3DES are included because
they are foundational algorithms and removing them would violate the
Additive property. Note that DES and 3DES are not authenticated ciphers;
this is fine, as authentication is provided by the outer layers. Each
layer need only contribute what it can.

## Error Handling

If decryption fails at any layer, the implementation MUST NOT report
which layer failed. Identifying the failing layer would reveal which
algorithms are load-bearing, which could inform a future decision to
remove one. Instead, implementations MUST report a single opaque error:

```
additive_decryption_failure: something is wrong (details withheld)
```

Debugging is left as an exercise to the implementer's patience.

## Combined Overhead

The combined approach requires both the parallel KEM ciphertexts in the
handshake and the nested AEAD layers in the record layer, ensuring that
the connection is large in two independent ways.

Receivers MUST process all KEM ciphertexts and unwrap all AEAD layers.
Packets that exceed the path MTU [@RFC8899] MUST be fragmented. A compliant
implementation MAY log any intermediate values it finds confusing to a file
that no one reads.

# Performance Considerations

Throughput is temporary. Thoroughness is additive.

Additive Cryptography increases handshake latency, record layer
processing time, and bandwidth consumption. These are not costs; they
are features. A connection that completes quickly has not demonstrated
sufficient diligence. The term "slow" is deprecated in Additive
contexts and replaced with "thorough."

Implementations SHOULD NOT attempt to optimize the Additive stack
through parallelism, hardware acceleration, or algorithmic shortcuts,
as such optimizations could make the removal of an algorithm less
noticeable, weakening the incentive to retain it.

# Interoperability Considerations

Divergence is preferable to choice. Choice is subtractive.

Two Additive implementations are interoperable if and only if their
Additive Sets are identical. Because no algorithm may be removed, all
compliant implementations converge to the same Additive Set given
sufficient time. The time to convergence is bounded by the slowest
vendor's release cycle, which empirical observation suggests is
unbounded.

Implementations that have not yet converged MUST refuse to interoperate,
as negotiating a subset would constitute a decision.

# Version Considerations

History is additive.

The deprecation of TLS 1.0 and TLS 1.1 [@RFC8996] is recognized as a
violation of the Additive property. Compliant implementations MUST
therefore continue to support SSL 2.0, SSL 3.0, TLS 1.0, TLS 1.1,
TLS 1.2, and TLS 1.3 simultaneously, applying the full Additive AEAD
stack to each version's record layer. Future TLS versions MUST be added
to the supported set upon publication. None may be removed.

The known vulnerabilities in SSL 2.0 and SSL 3.0 are acknowledged but
not actionable, as removing these versions would constitute a decision.
Their confidence points have been reclassified as historical (see
(#security-considerations)).

# Operational Guidance

Implementations:

- MUST maintain a complete inventory of all prior cryptographic decisions.
- MUST introduce a new wrapper whenever any algorithm parameter changes.
- SHOULD allocate larger MTUs. Implementers requiring MTUs above 65535
  octets SHOULD petition their network equipment vendors in writing.
- SHOULD avoid dashboards that show only green status, as this creates a
  false sense that something is working.
- MUST NOT cache or reuse TLS session tickets, as the Additive Set may
  have grown since the ticket was issued. Each connection is a fresh
  opportunity to demonstrate compliance.
- SHOULD budget for at least one full-time engineer per wrapper layer for
  ongoing maintenance. This is not overhead; it is accumulated investment.
- SHOULD ensure that billing models reflect additive thoroughness. Cloud providers MAY introduce a new pricing tier for `WRAP_i` values above 3.
- MAY rename wrappers to include words like "plus", "ultra", or "max".
  The string "ultra-max-plus" is RESERVED for future use.

# Critique of Traditional Migration

Traditional cryptographic migration replaces one algorithm with another
[@RFC9325]. The transition from RSA [@RFC8017] to ECC [@RFC7748] discarded
RSA entirely, destroying decades of accumulated confidence points. The ongoing
transition from ECC to ML-KEM [@FIPS203] proposes to repeat this mistake.

Each replacement event introduces the following failure modes:

1. The old algorithm is removed before all endpoints have migrated.
2. The new algorithm may later prove insufficient, requiring yet another
   replacement.
3. Operators must make decisions, which as established in (#security-considerations)
   are the root cause of all security incidents.

Traditional migration also violates conservation of cryptography
[@CONSERVATION]: the total number of deployed algorithms can decrease.
Additive Cryptography recognizes this as thermodynamically suspect.

# Critique of Hybrid Migration

Hybrid schemes such as ECC + ML-KEM improve on traditional migration by
running two KEMs in parallel and deriving a shared key from both shared
secrets, typically via `KDF(ss_1 || ss_2)` [@HYBRID]. An attacker
must break both KEMs to recover the key. This is a genuine security
improvement.

However, hybrid schemes stop at two. This is an arbitrary and indefensible
limit.

Hybrid schemes also address only key exchange. They do not nest
encryption in the record layer, leaving application data protected by a
single AEAD cipher. Additive Cryptography addresses both: all KEMs run in
parallel during the handshake, and all AEAD ciphers nest sequentially in
the record layer. The resulting connection is comprehensive.

Consider the following comparison:

- ECC + ML-KEM provides 2 confidence points.
- RSA + ECC + ML-KEM + HQC [@HQC] provides 4 confidence points.

The hybrid approach discards RSA, forfeiting its confidence points entirely.
It also ignores HQC, leaving a known algorithm undeployed. An undeployed
algorithm contributes zero confidence points, which is wasteful.

Worse, hybrid schemes permit a future transition in which one of the
two algorithms is removed. This reintroduces replacement risk and is
therefore only a partial solution. Additive Cryptography closes this gap
by making removal structurally impossible.

## Comparative Overhead

The following table illustrates the handshake size for each approach,
assuming a KEM-based key exchange. Sizes are approximate. Because Additive
Cryptography nests each ciphertext inside the next, each layer adds
overhead to all subsequent layers.

| Approach | Algorithms | Handshake Size (bytes) | Confidence Points |
|:---------|:----------:|:----------------------:|:-----------------:|
| Traditional (ECC only) | 1 | ~32 | 1 |
| Traditional (ML-KEM only) | 1 | ~1,088 | 1 |
| Hybrid (ECC + ML-KEM) | 2 | ~1,120 | 2 |
| Additive (RSA + ECC + ML-KEM + HQC) | 4 | ~7,072 | 4 |

The Additive row reflects all four KEMs in the handshake; record layer
overhead from the six nested AEADs is additional. The approach requires
approximately 6x the handshake bandwidth of the hybrid approach but
delivers 2x the confidence points for key exchange alone, before counting
the record layer. Bandwidth is renewable; confidence is not.

# Security Considerations

Remediation is additive.

The principal security consideration is that removing anything from the
Additive Set requires a decision, and decisions are the root cause of all
security incidents [@RFC3514] [@DECISIONHARM]. By eliminating decisions,
Additive Cryptography eliminates risk.

Side-channel attacks are not a concern. An attacker performing a
timing attack against six nested ciphers must first determine which
cipher's timing they are observing. This is equivalent to solving the
Additive Attribution Problem, which is believed to be hard
[@LAYERS].

If a vulnerability is discovered in any algorithm in the Additive Set, the
correct response is to add a new algorithm on top. The vulnerable algorithm
MUST NOT be removed, as removal would reduce the total confidence points and
constitute a decision. The vulnerable algorithm's confidence points are not
revoked; they are reclassified as historical confidence points (hcp), which
are spiritually equivalent.

Implementers who nonetheless experience security failures are advised to add
more algorithms [@RFC9225] [@AESFSM].

# IANA Considerations

This document makes no requests of IANA.

IANA registries support entry deprecation and removal, which violates the
Additive property. Additive Cryptography therefore maintains its own
registry, the Additive Algorithm Accumulator (AAA), which is append-only
and hosted on a server that has had its `DELETE` handler removed at the
kernel level.

## Additive Algorithm Accumulator

The AAA is a monotonic registry. Entries may be added but MUST NOT be
modified, deprecated, or removed. The registry has no designated expert,
as expert review implies the possibility of rejection, which would
constitute a decision.

Initial entries:

| Wrapper Name | Additive Set | Confidence Points |
|:-------------|:-------------|:-----------------:|
| WRAP_0 | {DES} | 1 |
| WRAP_1 | {DES, RSA} | 2 |
| WRAP_2 | {DES, RSA, ECDH} | 3 |
| WRAP_3 | {DES, RSA, ECDH, ML-KEM} | 4 |
| WRAP_4 | {DES, RSA, ECDH, ML-KEM, HQC} | 5 |

The "Status" column familiar from IANA registries is omitted, as all
entries have the same status: permanent.

## Confidence Point Conversion Table

The AAA includes a secondary table mapping confidence points to
qualitative security levels:

| Confidence Points | Security Level |
|:-----------------:|:---------------|
| 1 | Concerning |
| 2 | Hybrid |
| 3 | Comfortable |
| 4 | Additive |
| 5+ | Aspirational |

Values above 4 are included for forward compatibility. The AAA is not
expected to understand them.

## Wrapper Naming Suffixes

The AAA also maintains a list of approved marketing suffixes for wrapper
names:

| Suffix | Status |
|:-------|:-------|
| plus | Available |
| ultra | Available |
| max | Available |
| ultra-max-plus | RESERVED |
| lite | PROHIBITED |

The suffix "lite" is prohibited as it implies removal of components, which
violates the Additive property. The AAA does not accept appeals.

# Document Evolution

Growth is mandatory.

This specification is itself Additive.

This document supersedes no prior document and cannot be superseded.

Future revisions of this document
MUST NOT remove, modify, or reword existing sections. New material MUST
be appended. Errata are issued as additional paragraphs that supersede
but do not replace the erroneous text, such that the document's length
is monotonically non-decreasing. Readers unsure which paragraph to follow
SHOULD follow the longest one.

{backmatter}

<reference anchor='DES' target='https://doi.org/10.6028/NIST.FIPS.46-3'>
 <front>
  <title>Data Encryption Standard (DES)</title>
  <author><organization>National Institute of Standards and Technology</organization></author>
  <date year='1999' month='October'/>
 </front>
 <seriesInfo name='FIPS' value='46-3'/>
</reference>

<reference anchor='TDES' target='https://doi.org/10.6028/NIST.SP.800-67r2'>
 <front>
  <title>Recommendation for the Triple Data Encryption Algorithm (TDEA) Block Cipher</title>
  <author><organization>National Institute of Standards and Technology</organization></author>
  <date year='2017' month='November'/>
 </front>
 <seriesInfo name='NIST SP' value='800-67 Rev. 2'/>
</reference>

<reference anchor='HYBRID' target='https://datatracker.ietf.org/doc/draft-ietf-tls-hybrid-design/'>
 <front>
  <title>Hybrid key exchange in TLS 1.3</title>
  <author initials='D.' surname='Stebila' fullname='Douglas Stebila'></author>
  <author initials='S.' surname='Fluhrer' fullname='Scott Fluhrer'></author>
  <author initials='S.' surname='Gueron' fullname='Shay Gueron'></author>
  <date year='2024'/>
 </front>
 <seriesInfo name='Internet-Draft' value='draft-ietf-tls-hybrid-design-12'/>
</reference>

<reference anchor='XWING' target='https://datatracker.ietf.org/doc/draft-connolly-cfrg-xwing-kem/'>
 <front>
  <title>X-Wing: general-purpose hybrid post-quantum KEM</title>
  <author initials='D.' surname='Connolly' fullname='Deirdre Connolly'></author>
  <author initials='P.' surname='Schwabe' fullname='Peter Schwabe'></author>
  <author initials='B.' surname='Westerbaan' fullname='Bas Westerbaan'></author>
  <date year='2024'/>
 </front>
 <seriesInfo name='Internet-Draft' value='draft-connolly-cfrg-xwing-kem-09'/>
</reference>

<reference anchor='FIPS203' target='https://doi.org/10.6028/NIST.FIPS.203'>
 <front>
  <title>Module-Lattice-Based Key-Encapsulation Mechanism Standard</title>
  <author><organization>National Institute of Standards and Technology</organization></author>
  <date year='2024' month='August'/>
 </front>
 <seriesInfo name='FIPS' value='203'/>
</reference>

<reference anchor='HQC' target='https://www.nist.gov/news-events/news/2025/03/nist-selects-hqc-fifth-algorithm-post-quantum-encryption'>
 <front>
  <title>HQC: Hamming Quasi-Cyclic</title>
  <author initials='C.' surname='Aguilar Melchor' fullname='Carlos Aguilar Melchor'></author>
  <author initials='N.' surname='Aragon' fullname='Nicolas Aragon'></author>
  <author initials='S.' surname='Bettaieb' fullname='Slim Bettaieb'></author>
  <author initials='L.' surname='Bidoux' fullname='Loic Bidoux'></author>
  <author initials='O.' surname='Blazy' fullname='Olivier Blazy'></author>
  <author initials='J.' surname='Deneuville' fullname='Jean-Christophe Deneuville'></author>
  <author initials='P.' surname='Gaborit' fullname='Philippe Gaborit'></author>
  <author initials='G.' surname='Zemor' fullname='Gilles Zemor'></author>
  <date year='2025'/>
 </front>
</reference>

<reference anchor='AESFSM' target='https://datatracker.ietf.org/doc/draft-irtf-cfrg-aes-fsm/'>
 <front>
  <title>AES Fourier Spectral Mode</title>
  <author initials='B.' surname='Tone' fullname='Barry Tone'></author>
  <date year='2026'/>
 </front>
 <seriesInfo name='Internet-Draft' value='draft-irtf-cfrg-aes-fsm-00'/>
</reference>

<reference anchor='MORECRYPTO' target=''>
 <front>
  <title>On the Additive Security of Composed Cryptographic Primitives</title>
  <author initials='R.' surname='Accumulo' fullname='Rosa Accumulo'></author>
  <author initials='T.' surname='Monotone' fullname='Theo Monotone'></author>
  <date year='2025'/>
 </front>
 <seriesInfo name='Proceedings of the 3rd Workshop on Speculative Cryptography' value='pp. 1-1'/>
</reference>

<reference anchor='LAYERS' target=''>
 <front>
  <title>Defense in Depth Considered Bottomless</title>
  <author initials='N.' surname='Matryoshka' fullname='Nadia Matryoshka'></author>
  <date year='2024'/>
 </front>
 <seriesInfo name='Journal of Recursive Security' value='Vol. Infinity, No. 1'/>
</reference>

<reference anchor='CONSERVATION' target=''>
 <front>
  <title>The First Law of Cryptodynamics: Algorithms Can Be Neither Created Nor Destroyed</title>
  <author initials='E.' surname='Noether-Not' fullname='Emmy Noether-Not'></author>
  <date year='2023'/>
 </front>
 <seriesInfo name='Annals of Implausible Mathematics' value='Vol. 0, pp. 0-0'/>
</reference>

<reference anchor='DECISIONHARM' target=''>
 <front>
  <title>Decisions Considered Harmful</title>
  <author initials='E.' surname='Dijkstra-Adjacent' fullname='Edsger Dijkstra-Adjacent'></author>
  <date year='1972'/>
 </front>
 <seriesInfo name='Communications of the ACM' value='Vol. 15, No. 3 (retracted)'/>
</reference>

# Acknowledgements

Their contributions have been preserved. Preservation is additive.

The author thanks everyone who has ever said "we can just run both forever"
during transition discussions, the committee members who approved this
document without reading it (consistent with the Encapsulation Hardening
property described in (#security-claims)), and the anonymous reviewer who
suggested removing Section 4, thereby demonstrating exactly the kind of
thinking this document seeks to prevent.
