---
name: freedom-privacy
description: Comprehensive reference for the Freedom privacy proxy — architecture, cryptographic design, trust model, data handling, and what Freedom does and doesn't protect. Use this skill whenever writing about Freedom's privacy, security, or trust properties, creating marketing copy, answering user questions about privacy, writing documentation, designing UI copy about privacy features, handling privacy-related issues or PRs, or explaining how Freedom works to any audience. Also use when someone asks about the proxy, tokens, Cloudflare, DNS, metadata, VPN vs proxy, or any trust-related question about Freedom.
---

# Freedom Privacy Reference

Freedom is a government-released privacy proxy that routes internet traffic through Cloudflare's Privacy Proxy infrastructure. It is **not a traditional VPN** — it is an HTTP CONNECT proxy authenticated with Privacy Pass blind RSA tokens, designed so that no single party (including the government that built it) can link a user's identity to their browsing activity.

The entire client codebase is open source. This document is the authoritative reference for all privacy-related claims, technical architecture, limitations, and messaging guidance.

---

## Table of Contents

1. [What Freedom Is](#what-freedom-is)
2. [Architecture & Traffic Flow](#architecture--traffic-flow)
3. [Privacy Pass Tokens](#privacy-pass-tokens)
4. [Encryption & Protocols](#encryption--protocols)
5. [Certificate Pinning](#certificate-pinning)
6. [What Freedom Collects](#what-freedom-collects)
7. [What Freedom Does NOT Collect](#what-freedom-does-not-collect)
8. [Ad & Tracker Blocking](#ad--tracker-blocking)
9. [Kill Switch](#kill-switch)
10. [What Freedom Protects](#what-freedom-protects)
11. [What Freedom Does NOT Protect](#what-freedom-does-not-protect)
12. [Trust Model](#trust-model)
13. [Known Limitations (Be Honest About These)](#known-limitations)
14. [Comparison: Freedom vs VPN vs Tor](#comparison-freedom-vs-vpn-vs-tor)
15. [Common Questions & Messaging Guidance](#common-questions--messaging-guidance)
16. [Technical Reference Values](#technical-reference-values)
17. [Codebase Map](#codebase-map)

---

## What Freedom Is

Freedom is a **privacy proxy client** built in Rust that creates encrypted HTTP CONNECT tunnels through Cloudflare's Privacy Proxy. It is available as a desktop app (macOS, Windows, Linux) and mobile app (Android, iOS).

**What it is:**
- An HTTP CONNECT proxy over HTTP/2 or HTTP/3 (QUIC)
- Authenticated with Privacy Pass blind RSA tokens (no accounts)
- Open source client with Cloudflare-operated proxy infrastructure
- Free, no account required, no payment required

**What it is NOT:**
- A traditional VPN (does not create a full IP tunnel for all protocol types)
- An anonymity network like Tor (single hop, not multi-hop)
- A security suite (no antivirus, no anti-phishing beyond ad-block)
- A government surveillance tool (architecture makes surveillance structurally impossible)

---

## Architecture & Traffic Flow

### Desktop (TUN mode)

```
App on device
    ↓ (TCP packet)
TUN interface (10.0.85.1/24, MTU 1400)
    ↓ (parsed by TcpHandler)
TCP connection → HTTP CONNECT stream
    ↓ (multiplexed over single persistent connection)
Encrypted tunnel (TLS 1.3 / QUIC)
    ↓
Cloudflare Privacy Proxy (connect.freedom.gov:443)
    ↓
Destination website
```

### Desktop (System Proxy mode)

```
App on device
    ↓ (HTTP/HTTPS request)
System proxy settings → 127.0.0.1:9080
    ↓
Local HTTP CONNECT proxy
    ↓ (CONNECT stream)
Encrypted tunnel to Cloudflare
    ↓
Destination website
```

### Android

```
App on device
    ↓
Android VPN Service (TUN)
    ↓
tun2proxy bridge → local HTTP CONNECT proxy
    ↓
Encrypted tunnel to Cloudflare
    ↓
Destination website
```

### Critical architectural fact

**The government is NOT in the data path.** The government's role is limited to:
1. Building the client software (open source, auditable)
2. Operating the token issuance endpoint (uses blind signatures — cannot link tokens to usage)
3. Distributing the app through app stores

All traffic proxying is handled by Cloudflare. The government never sees, processes, or touches user traffic.

---

## Privacy Pass Tokens

Freedom uses **Privacy Pass** (blind RSA signatures) for authentication. This is the core privacy innovation — it mathematically separates the act of proving you're legitimate from the act of using the service.

### How it works

**Phase 1 — Token Issuance:**
1. User completes a Turnstile challenge (proves they're human)
2. Client generates tokens and "blinds" them cryptographically
3. Blinded tokens are sent to the issuance server (connect.freedom.gov)
4. Server signs the blinded tokens **without being able to see their actual values**
5. Client "unblinds" the signed tokens locally
6. Result: tokens that are valid (server-signed) but unlinkable to the issuance event

**Phase 2 — Token Redemption:**
1. Client randomly selects a token from the batch (random selection prevents ordering correlation)
2. Token is presented to Cloudflare's Privacy Proxy in the first CONNECT request
3. Proxy verifies the token is valid (signed by legitimate issuer)
4. Proxy **cannot determine** when the token was issued, to whom, or from which batch

### Why this matters

- The token issuer (government) **cannot see** what the final tokens look like
- The proxy (Cloudflare) **cannot link** tokens to issuance events
- Even if the issuer and proxy collude and share all data, they **cannot connect** the dots
- This is a **mathematical guarantee** from the RSA blind signature scheme, not a policy promise

### Token lifecycle

- **Default lifetime:** 14 days (1,209,600 seconds)
- **Expiry buffer:** Tokens pruned 5 minutes before expiry
- **Refresh trigger:** When fewer than 3 tokens remain or all expire within 1 hour
- **Selection:** Random (not sequential) to prevent timing-based correlation
- **Format:** `PrivateToken token=<base64url>` (production) or `Preshared <key>` (testing)
- **Storage:** In-memory token pool, never written to disk

---

## Encryption & Protocols

### Transport layer

Freedom supports two transport protocols:

**HTTP/2 (default):**
- Single persistent TLS 1.3 connection over TCP:443
- Multiplexes CONNECT streams (one per destination)
- HTTP/2 flow control for per-stream bandwidth management

**HTTP/3 (QUIC):**
- Single persistent QUIC connection over UDP
- Built-in encryption (no separate TLS handshake)
- Lower latency, better performance on unreliable/mobile networks
- Max datagram size: 1,452 bytes (accounting for IPv6/UDP headers)
- Max write buffer: 10 MB per stream
- Max pending opens: 1,024 concurrent CONNECT requests

### H3 → H2 fallback

If H3 encounters 3 transport-level failures (QUIC errors, I/O errors, timeouts), Freedom automatically falls back to H2. The counter resets on successful H3 connection or new token batch.

Failures that trigger fallback: pre-connect failure, reconnect failure, QUIC/H3 session error, session None.

Failures that do NOT trigger fallback: ConnectRejected (stream-level), 401 auth errors, NoTokens.

### Cryptographic libraries

Freedom does NOT implement custom cryptography. It uses:
- **rustls** — TLS implementation backed by the Ring crypto library
- **quiche** — Cloudflare's QUIC/HTTP/3 implementation (used in Cloudflare's own production network)
- **h2** — HTTP/2 implementation for Rust
- **webpki-roots** — Mozilla's root certificate store (same as Firefox)

These are the most widely used, continuously audited networking and crypto libraries in the Rust ecosystem.

---

## Certificate Pinning

Freedom implements SPKI (Subject Public Key Info) SHA-256 certificate pinning to prevent man-in-the-middle attacks.

### What it does

During the TLS handshake, Freedom computes the SHA-256 hash of each certificate's Subject Public Key Info in the chain and compares it against a hardcoded list of known-good pins. If no certificate in the chain matches a pin, the connection is rejected — even if the certificate is signed by a trusted CA.

### Why it matters

Without certificate pinning, a government or ISP that controls a Certificate Authority could issue a fraudulent certificate for the proxy hostname and intercept traffic. This has happened in the real world (e.g., DigiNotar incident). Certificate pinning makes this attack impossible — the attacker would need to modify the open-source code, which would be visible to everyone.

### Pinned certificates

The pins are for Cloudflare's infrastructure and their CA providers (Google Trust Services, DigiCert). They are NOT government certificates. Hardcoded in the source code at `freedom-rust/src/tunnel/h2_session.rs`.

---

## What Freedom Collects

### On the client (your device)

- **Session statistics (in-memory only, never transmitted):** bytes sent/received, unique domains visited, top domains, ad-block counts, recently blocked domains, uptime, latency
- **Onboarding state:** A single boolean flag indicating whether onboarding was completed
- **Settings:** Protocol preference (H2/H3), environment, ad-block toggles, kill switch preference
- **Device ID:** A locally-generated UUID stored at `~/.freedom/.device_id` — used for incident reports only
- **Incident reports (local):** Crash diagnostics with network snapshots (interface name, gateway, memory usage) — stored at `~/.freedom/incidents/`, max 100 files

### On the token issuance server (government)

- That someone completed a Turnstile challenge at a given time (but cannot link this to subsequent token usage)
- That tokens were issued (but cannot see what those tokens look like after unblinding)

### On the proxy (Cloudflare)

- That someone presented a valid token
- The destination domain of each CONNECT request (e.g., `example.com:443`)
- The timing and volume of traffic through the tunnel
- Cloudflare **cannot** identify who is making the request (Privacy Pass prevents this)

---

## What Freedom Does NOT Collect

This is verifiable in the source code. There is no code that:

- Logs URLs, page content, form submissions, or any traffic content
- Records browsing history
- Stores or transmits passwords or credentials
- Sets or reads cookies or session identifiers
- Tracks search queries
- Sends user PII to any server
- Creates persistent user profiles
- Fingerprints devices for tracking
- Correlates sessions across connections
- Phones home with usage telemetry in production builds

### Telemetry

The codebase contains telemetry infrastructure (OpenTelemetry + Axiom integration) gated behind a **compile-time feature flag** (`--features telemetry`). This means:

- Production builds are compiled **without** the telemetry feature
- The telemetry code is **not present in the production binary** — Rust's conditional compilation (`#[cfg(feature = "telemetry")]`) excludes it entirely
- When enabled for development, it logs operational metrics (connection counts, protocol negotiation) — never traffic content or user data
- The feature flag, conditional compilation, and default build profile are all visible in `Cargo.toml`

---

## Ad & Tracker Blocking

Freedom includes optional domain-level ad and tracker blocking.

### How it works

- Uses a **Finite State Transducer (FST)** for memory-efficient domain matching
- Compresses 163,000+ domains into ~1-2 MB (vs ~16 MB for a HashMap)
- Lock-free hot path via `ArcSwap` — no locks on the blocking check
- Domain hierarchy walk: checks `ads.tracker.example.com`, then `tracker.example.com`, then `example.com`

### Categories

- **Ads & Trackers:** Known advertising networks and tracking domains (163K+ domains)
- **Adult Content:** Optional filter for adult websites (user-togglable)

### Blocklist management

- Fetched from Freedom API with manifest-based updates
- Cached locally with atomic write-then-rename
- Max 500,000 domains per blocklist
- Refresh interval: every 6 hours (configurable)
- Hot-swappable: toggles can be changed while connected without reconnecting

---

## Kill Switch

The kill switch prevents data leaks if the VPN connection drops unexpectedly.

### How it works

- When the kill switch is **enabled** and the proxy crashes, the system proxy settings remain configured to route through Freedom's (now-dead) proxy → internet traffic is blocked
- When the kill switch is **disabled**, a watchdog process monitors the main process and clears system proxy settings on crash → internet traffic flows directly (unprotected)

### Implementation

- Spawns a detached helper process that monitors the parent via sentinel file
- Helper polls every 1 second for parent process death or sentinel deletion
- On parent death with kill switch disabled: calls `platform::clear_system_proxy()` to restore direct internet
- On parent death with kill switch enabled: does nothing → traffic stays blocked
- Sentinel files stored in `{TEMP}/freedom-proxy-cleanup/`
- Platform-specific: Unix uses SIGKILL check, Windows uses OpenProcess + WaitForSingleObject

### Panic recovery

Even on Rust panics, a synchronous cleanup hook reads `/tmp/freedom-proxy-state.json` to find active network services and disables the proxy for each one. This ensures the system proxy is always cleaned up correctly.

---

## What Freedom Protects

### Your IP address from websites
Websites see Cloudflare's IP, not yours. This prevents IP-based location tracking, geographic profiling, and IP-based cross-site tracking.

### Your traffic content from network observers
The encrypted tunnel (TLS 1.3 or QUIC) prevents your ISP, network administrator, coffee shop Wi-Fi operator, or anyone on your local network from seeing which specific websites you visit or what data you exchange.

### Your identity from the proxy operator
Privacy Pass blind tokens make it mathematically impossible for Cloudflare to link your identity to your traffic. There are no accounts, no persistent identifiers, and no authentication tokens that survive across sessions.

### Access to censored content
Because traffic appears as an encrypted connection to Cloudflare (one of the most common destinations on the internet), censors cannot easily block Freedom without blocking a significant portion of the internet.

---

## What Freedom Does NOT Protect

**Always be honest about these in any user-facing communication.** Overstating Freedom's protections destroys trust.

### DNS queries
DNS is excluded from the proxy tunnel. Queries go directly to encrypted resolvers (1.1.1.1, 8.8.8.8). Without DNS over HTTPS (DoH) or DNS over TLS (DoT) enabled on the user's device, domain lookups are visible on the local network.

**Why:** DNS exclusion prevents routing loops — the proxy connection itself needs DNS to resolve.

**User action:** Enable DNS over HTTPS in browser settings.

### Non-HTTP traffic
Freedom proxies TCP traffic through HTTP CONNECT tunnels. This covers web browsing, HTTPS APIs, most app communications, and streaming. It does NOT cover raw UDP (except QUIC), ICMP, or custom protocols (some gaming, VoIP, P2P).

### Your identity when you log in
If you sign into Google, Facebook, Twitter, or any other account, those services know who you are — because you told them. Freedom hides your IP, not your login credentials.

### Browser fingerprinting
Websites can identify you through browser fingerprint data (screen resolution, fonts, timezone, hardware, etc.). Freedom operates at the network level and does not modify the browser.

### Metadata patterns
Your ISP can see: that you're connected to Cloudflare, when, and how much data flows. Cloudflare can see: which domains you're connecting to, connection timing, traffic volume. These patterns can theoretically be used for traffic analysis by sophisticated adversaries.

### Protection from malware or phishing
Freedom is a privacy tool, not a security suite. It does not scan downloads, block phishing sites (beyond the ad-block list), or prevent social engineering.

### Complete anonymity
No single tool provides complete anonymity. The Turnstile challenge sees your IP during token acquisition. Connection timing can theoretically be correlated. Your ISP knows you use Freedom.

---

## Trust Model

### What you trust

1. **The open-source code** — readable, auditable, verifiable by anyone
2. **Cloudflare's infrastructure** — that they faithfully implement the Privacy Proxy protocol
3. **The mathematics** — that blind RSA signatures provide unlinkability (well-studied, provable)
4. **Your device** — that your operating system isn't compromised

### What you do NOT need to trust

1. **The government's intentions** — the architecture prevents surveillance regardless of intent
2. **That logs aren't being kept** — there's no code that creates them on the client, and the proxy can't identify users
3. **Marketing promises** — every privacy claim is verifiable in the source code

### What could go wrong

- **Cloudflare compromised or coerced** — could break unlinkability on the server side. Mitigated by business incentives and protocol verifiability.
- **Critical code bug** — could weaken privacy guarantees. Mitigated by open source review and planned independent audits.
- **Token issuance shutdown** — government could disable Freedom. Existing tokens work until expiry (up to 14 days).
- **Compromised update** — malicious code pushed as update. Mitigated by open source visibility, version control history, app store review.
- **Supply chain attack** — binary differs from source. Mitigated by open build scripts, dependency pinning (`Cargo.lock`), reproducible builds.

---

## Known Limitations

When writing about Freedom, never hide these. Radical transparency is the policy.

| Limitation | Detail | Mitigation |
|---|---|---|
| DNS not proxied | DNS goes directly to 1.1.1.1/8.8.8.8 | Enable DoH/DoT in browser |
| Not a full VPN | Only TCP traffic proxied via HTTP CONNECT | Covers 95%+ of typical web traffic |
| Single proxy hop | Less anonymous than Tor's 3-hop architecture | Deliberate tradeoff for performance; Privacy Pass adds unlinkability |
| Cloudflare is a trust point | Server-side code is not open source | Protocol properties are client-verifiable; business incentives align |
| No independent audit yet | No published third-party security assessment | Open source code available for community review; audit planned |
| Metadata visible | Timing, volume, and destination domains observable | Connection multiplexing reduces granularity |
| Government controls token issuance | Could deny service or shut down | Open source code can be forked; backup tools (Tor) recommended |
| Telemetry code exists in source | Could theoretically be enabled in a future build | Feature-gated at compile time; visible in `Cargo.toml` |

---

## Comparison: Freedom vs VPN vs Tor

| | Freedom | Traditional VPN | Tor |
|---|---|---|---|
| **Architecture** | HTTP CONNECT proxy | IP tunnel | 3-hop onion routing |
| **Traffic covered** | TCP (HTTP/HTTPS) | All (TCP/UDP/ICMP) | TCP (primarily via browser) |
| **Authentication** | Anonymous blind tokens | Account (email + payment) | None |
| **Operator knowledge** | Proxy sees destinations, not identity | VPN sees identity + destinations | No single node sees both |
| **Code** | Fully open source | Usually closed source | Fully open source |
| **Cost** | Free, no account | Paid subscription | Free |
| **Speed** | Fast (single hop, H2/H3) | Varies | Slow (3 hops) |
| **Anonymity** | Strong privacy, not full anonymity | Weak (operator knows you) | Strong anonymity |
| **DNS** | Excluded (direct to resolver) | Usually tunneled | Tunneled via Tor |
| **Kill switch** | Yes | Yes (most) | N/A (browser-based) |
| **Best for** | Everyday privacy, censorship bypass | Full traffic protection | High-risk anonymity |

---

## Common Questions & Messaging Guidance

### "Why should I trust a government VPN?"

**Never say:** "Trust us" or "We promise not to spy."

**Always say:** The architecture makes surveillance structurally impossible. The government doesn't handle your traffic (Cloudflare does). The authentication uses blind signatures (mathematically unlinkable). The code is open source (verify it yourself). You don't need to trust anyone — you need to verify the code and the math.

### "Is Freedom a VPN?"

**Be precise:** Freedom is a privacy proxy, not a traditional VPN. It routes TCP traffic through encrypted HTTP CONNECT tunnels via Cloudflare. For most users (web browsing, apps, streaming), this covers essentially all their traffic. It does not tunnel UDP, ICMP, or exotic protocols like a traditional VPN would.

### "Can the government see what I'm doing?"

**Direct answer:** No. Your traffic flows through Cloudflare, not government infrastructure. The government built the client (open source) and operates the token server (blind signatures prevent linking). They are never in the data path.

### "Can Cloudflare see what I'm doing?"

**Honest answer:** Cloudflare can see which domains you connect to and traffic patterns (timing, volume). They cannot see traffic content (it's encrypted end-to-end). They cannot identify who you are (Privacy Pass prevents this). They see "someone with a valid token is connecting to example.com" — not "user X is connecting to example.com."

### "Is this better than a VPN?"

**Nuanced answer:** It depends on your needs. Freedom provides stronger privacy guarantees (no accounts, blind tokens, open source) but covers less traffic (TCP only, DNS excluded). For everyday web browsing and censorship bypass, Freedom provides more verifiable privacy than most commercial VPNs. For full traffic protection or server location selection, a traditional VPN may be more appropriate.

### "What about Tor?"

**Honest answer:** For strong anonymity against sophisticated adversaries, use Tor. Freedom is designed for everyday privacy — fast, usable, system-wide. Tor is designed for high-risk anonymity — slower, primarily browser-based, multi-hop. They serve different threat models and can be used together.

### "What if the government shuts it down?"

**Transparent answer:** The government controls the token issuance server and could shut it down. Existing tokens work until they expire (up to 14 days). The code is open source and can be forked. Users should maintain backup privacy tools (Tor, commercial VPNs).

### "How do I know the binary matches the source code?"

**Honest answer:** Build scripts are open source. Dependencies are pinned in `Cargo.lock`. App store distribution adds code signing verification. For maximum assurance, build from source yourself.

---

## Technical Reference Values

### Network Configuration
- TUN IP: `10.0.85.1/24`
- TUN MTU: 1400
- TUN device names: `utun9` (macOS), `tun0` (Linux), `PrivacyProxy` (Windows)
- DNS servers (excluded from proxy): `1.1.1.1`, `1.0.0.1`, `8.8.8.8`, `8.8.4.4`
- Desktop proxy port: `9080` (preferred), auto-assigned fallback
- Token callback port: `9876`

### Proxy Endpoints
- Production: `connect.freedom.gov:443`
- Staging: `staging.connect.freedom.gov:443`
- Testing: `cp-testing.cloudflare.com:443`
- API: `https://freedom.based.ceo`

### Token Configuration
- Default lifetime: 14 days (1,209,600 seconds)
- Expiry buffer: 5 minutes
- Refresh trigger: < 3 tokens remaining OR all expire within 1 hour
- Format: `PrivateToken token=<base64url>` (production), `Preshared <key>` (testing)

### Protocol Limits
- H3 max datagram: 1,452 bytes
- H3 max write buffer: 10 MB per stream
- H3 max pending opens: 1,024
- H3 fallback threshold: 3 transport failures
- Reconnection max retries: 3

### Ad-Block
- Domain count: 163,000+ (ads/trackers category)
- Max domains per blocklist: 500,000
- FST memory: ~1-2 MB for 163K domains
- Refresh interval: 6 hours
- Max manifest size: 5 MB
- Max list size: 50 MB per category

### Incident Tracking
- Snapshot interval: 5 seconds
- Ring buffer: 50 snapshots
- Max incident files: 100
- Upload interval: 60 seconds (after 15s startup delay)

---

## Codebase Map

### freedom-rust (proxy engine)

| Path | Purpose |
|---|---|
| `src/config.rs` | Environment config, TUN settings, excluded IPs |
| `src/tunnel/manager.rs` | TunnelManager: protocol dispatch, H3→H2 fallback, retry logic |
| `src/tunnel/h2_session.rs` | HTTP/2 session, TLS, certificate pinning |
| `src/tunnel/h3_session.rs` | HTTP/3 session, QUIC event loop |
| `src/tunnel/auth.rs` | TokenPool: random selection, expiry pruning, anti-correlation |
| `src/tunnel/stream.rs` | H2ProxyStream (AsyncRead/Write) |
| `src/tunnel/h3_stream.rs` | H3ProxyStream (AsyncRead/Write) |
| `src/token/mod.rs` | Token acquisition: API mode + browser verification |
| `src/ad_block/engine.rs` | AdBlockEngine: hot-path domain checking |
| `src/ad_block/matcher.rs` | DomainMatcher: FST-backed domain blocker |
| `src/tun/device.rs` | TUN device setup per platform |
| `src/tun/tcp_stack.rs` | TcpHandler: TCP state tracking, connection multiplexing |
| `src/platform/macos.rs` | macOS routing and system proxy |
| `src/platform/linux.rs` | Linux routing with iptables |
| `src/platform/windows.rs` | Windows routing with netsh |
| `src/local_proxy/runtime.rs` | ProxyRuntime: local HTTP CONNECT proxy |
| `src/local_proxy/session_manager.rs` | Session pool for concurrent streams |
| `src/telemetry.rs` | OpenTelemetry integration (feature-gated) |

### freedom-desktop (Tauri app)

| Path | Purpose |
|---|---|
| `src-tauri/src/lib.rs` | All Tauri commands, VPN lifecycle, token acquisition |
| `src-tauri/src/telemetry.rs` | IncidentTracker, Axiom upload, log rotation |
| `src-tauri/src/proxy_cleanup.rs` | Kill switch watchdog process |
| `src-tauri/src/ne_manager.rs` | macOS Network Extension FFI (App Store) |
| `src-tauri/src/windows.rs` | Windows network change detection + proxy restart |
| `src/pages/onboarding.tsx` | 4-step onboarding carousel |
| `src/pages/home.tsx` | Main VPN control UI, connect button, widgets |
| `src/components/widgets/*.tsx` | 17 session data widgets |
| `src/components/connected-widgets.tsx` | Widget grid layout |

### freedom-site (website)

| Path | Purpose |
|---|---|
| `app/[locale]/privacy/page.tsx` | Transparency/privacy page |
| `components/transparency/TransparencyPage.tsx` | Privacy page visual sections |
| `content/resources/en/why-trust-freedom.md` | Deep dive: why Freedom is trustworthy |
| `content/resources/en/reasons-not-to-trust-freedom.md` | Devil's advocate: 15 concerns |
| `content/resources/en/addressing-the-concerns.md` | Point-by-point responses |
| `content/resources/en/what-freedom-does-and-doesnt-do.md` | Definitive capabilities guide |
| `content/resources/en/how-freedom-works.md` | Technical architecture explainer |

---

## Messaging Principles

1. **Radical transparency over reassurance.** Never say "trust us." Always say "verify it yourself."
2. **Admit limitations before being asked.** Proactively stating what Freedom doesn't do builds more trust than only listing what it does.
3. **Math over policy.** "The blind signature scheme makes linking computationally infeasible" is stronger than "we promise not to log."
4. **Specific over vague.** "DNS queries go to 1.1.1.1, not through the proxy" is better than "some traffic may not be fully protected."
5. **Respect the user's intelligence.** Don't simplify to the point of inaccuracy. Users who care about privacy can handle technical details.
6. **Compare fairly.** Don't trash VPNs or Tor. Each tool serves a purpose. Freedom fills a specific niche — everyday privacy with verifiable guarantees.
7. **Government origin is a feature, not a bug.** It means sustained funding, app store distribution, and — because of the scrutiny it invites — more eyes on the code than most commercial alternatives.
8. **Open source is the trump card.** When in doubt, point to the code. Every claim should be verifiable.
