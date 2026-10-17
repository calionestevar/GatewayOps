# Contributing to Gateway Ops

Thank you for your interest in contributing! This project follows a **franchise-inspired naming convention** pattern to make the infrastructure more navigable and memorable. If you're extending this project, please respect the naming conventions below.

## Naming Convention: Stargate Universe

All new pipeline stages, scripts, and configuration files should follow the Stargate franchise naming pattern:

| Component Type | Naming Pattern | Examples |
|---------------|----------------|----------|
| **Build Jobs** | `[atlantis-tech]-[verb]` | `zpm-build`, `zpm-compile`, `asgard-encrypt` |
| **Validation Gates** | `[sg1-security]-[check]` | `iris-validation`, `chevron-lock`, `naquadah-check` |
| **Deploy Jobs** | `[gate-element]-[action]` | `gate-deploy`, `wormhole-routes`, `dial-home` |
| **Monitoring** | `[ufo/sensor]-[task]` | `destiny-monitor`, `asgard-beacon`, `symark-scan` |
| **Cleanup Scripts** | `[collapse-action]-[target]` | `dump-wormhole`, `recall-gate`, `evacuate-city` |

### Why This Convention Exists

At Cerner, we named our web layer components after Spider-Man characters and our data layer after Star Wars characters. The result: teammates could reference "send it to the Daily Bugle" or "route through Dagobah" and everyone understood what meant. The same principle applies here—shared cultural vocabulary reduces cognitive load and makes debugging more human.

## Adding a New Pipeline Stage

1. **Choose a franchise element** that matches the function:
   - Security/validation → SG-1 Iris/Chevron metaphors
   - Power/compute → Atlantis ZPM/Asgard metaphors
   - Navigation/routing → Dial Home Device/Gate metaphors
   - Long-term ops → Destiny ship metaphors

2. **Create the file** using kebab-case: `filename.yml` or `filename.sh`

3. **Document in this file** — Add a row to the Pipeline Stages table in README.md

4. **Add comments** to help future contributors understand the reference:
   ```yaml
   # zpm-build.yml
   # Atlantis ZPM (Zero Point Module) = power source that energizes the build