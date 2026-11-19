# PROTOTYPE results (#83): labeller variants on Walch sleep-accel 1.0.0

Tilt threshold 0.75° throughout. κ A / κ B: the two halves (even / odd positions by sorted id). Run with `swift run -c release sleep-wake-prototype <walch folder> [group ...]` (COMBOS, PER_NIGHT, STRAP env vars: see main.swift).

## Round 1: one change at a time

| Group | Variant | κ visible | Sens | Spec | κ raw | TA bias | TA SD | |Onset| > 60 min | κ A | κ B | Kept |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | spec 003 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| period | mergeMissing=5 | 0.340 | 0.891 | 0.568 | 0.445 | 0.6 | 76.2 | 2 | 0.462 | 0.241 | 28 |
| period | mergeMissing=15 | 0.390 | 0.923 | 0.536 | 0.445 | 16.1 | 40.5 | 1 | 0.482 | 0.312 | 28 |
| period | mergeMissing=30 | 0.390 | 0.923 | 0.536 | 0.445 | 16.1 | 40.5 | 1 | 0.482 | 0.312 | 28 |
| period | mergeMissing=60 | 0.390 | 0.923 | 0.536 | 0.445 | 16.1 | 40.5 | 1 | 0.482 | 0.312 | 28 |
| period | needsHR | 0.314 | 0.874 | 0.580 | 0.444 | -35.5 | 92.0 | 3 | 0.367 | 0.258 | 28 |
| period | longestSpan | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| period | merge=30 | 0.274 | 0.843 | 0.597 | 0.445 | -22.0 | 99.8 | 4 | 0.387 | 0.182 | 28 |
| period | merge=90 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| period | merge=120 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| period | merge=180 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| period | minRun=3 | 0.254 | 0.844 | 0.558 | 0.445 | -14.8 | 101.7 | 4 | 0.365 | 0.164 | 28 |
| period | minRun=5 | 0.262 | 0.844 | 0.573 | 0.445 | -17.9 | 101.2 | 4 | 0.367 | 0.176 | 28 |
| period | minRun=10 | 0.294 | 0.840 | 0.643 | 0.445 | -25.6 | 99.1 | 4 | 0.396 | 0.211 | 28 |
| period | minRun=15 | 0.290 | 0.831 | 0.661 | 0.445 | -30.8 | 104.5 | 3 | 0.380 | 0.216 | 28 |
| webster | webster | 0.295 | 0.841 | 0.642 | 0.497 | -25.0 | 99.3 | 4 | 0.398 | 0.211 | 28 |
| hr | hrWake=4.0 | 0.240 | 0.787 | 0.674 | 0.339 | -44.9 | 98.1 | 4 | 0.312 | 0.175 | 28 |
| hr | hrWake=6.0 | 0.249 | 0.817 | 0.618 | 0.383 | -31.2 | 99.8 | 4 | 0.340 | 0.171 | 28 |
| hr | hrWake=8.0 | 0.264 | 0.831 | 0.611 | 0.416 | -25.4 | 100.2 | 4 | 0.363 | 0.180 | 28 |
| hr | hrWake=10.0 | 0.273 | 0.838 | 0.607 | 0.434 | -22.3 | 100.5 | 4 | 0.383 | 0.182 | 28 |
| hr | hrWake=15.0 | 0.275 | 0.842 | 0.602 | 0.446 | -20.4 | 100.5 | 4 | 0.390 | 0.182 | 28 |
| hr | raisedHR=3.0 | 0.293 | 0.838 | 0.646 | 0.453 | -23.7 | 100.0 | 4 | 0.388 | 0.213 | 28 |
| hr | raisedHR=4.0 | 0.282 | 0.841 | 0.617 | 0.456 | -21.6 | 100.2 | 4 | 0.392 | 0.190 | 28 |
| hr | raisedHR=8.0 | 0.269 | 0.844 | 0.584 | 0.437 | -19.0 | 100.5 | 4 | 0.379 | 0.179 | 28 |
| hr | hrExtend=20 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| hr | hrExtend=30 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| vanhees | vanHees>2.0°±2 | 0.120 | 0.479 | 0.954 | 0.168 | -181.0 | 123.3 | 5 | 0.134 | 0.103 | 28 |
| vanhees | vanHees>3.0°±2 | 0.133 | 0.517 | 0.933 | 0.180 | -164.0 | 120.6 | 5 | 0.137 | 0.125 | 28 |
| vanhees | vanHees>5.0°±2 | 0.155 | 0.568 | 0.916 | 0.196 | -141.9 | 108.6 | 4 | 0.158 | 0.149 | 28 |
| vanhees | vanHees>8.0°±2 | 0.167 | 0.597 | 0.901 | 0.210 | -129.9 | 106.0 | 4 | 0.180 | 0.151 | 28 |
| pernight | perNight×3.0 | 0.003 | 0.032 | 0.984 | 0.001 | -376.7 | 90.4 | 26 | 0.004 | 0.001 | 28 |
| pernight | perNight×5.0 | 0.029 | 0.181 | 0.968 | 0.035 | -317.3 | 83.1 | 22 | 0.031 | 0.027 | 28 |
| pernight | perNight×10.0 | 0.078 | 0.467 | 0.812 | 0.096 | -199.1 | 115.1 | 13 | 0.067 | 0.092 | 28 |
| pernight | perNight×15.0 | 0.163 | 0.664 | 0.757 | 0.196 | -119.1 | 120.2 | 9 | 0.171 | 0.153 | 28 |
| grid | wakeActive=3 median5=2.0 | 0.268 | 0.763 | 0.799 | 0.369 | -61.2 | 99.1 | 3 | 0.309 | 0.226 | 28 |
| grid | wakeActive=3 median5=4.0 | 0.277 | 0.777 | 0.780 | 0.374 | -54.8 | 99.0 | 4 | 0.330 | 0.225 | 28 |
| grid | wakeActive=3 | 0.278 | 0.780 | 0.775 | 0.370 | -53.5 | 99.0 | 4 | 0.335 | 0.223 | 28 |
| grid | wakeActive=3 median5=9.0 | 0.278 | 0.782 | 0.773 | 0.368 | -52.9 | 99.0 | 4 | 0.335 | 0.224 | 28 |
| grid | wakeActive=5 median5=2.0 | 0.273 | 0.780 | 0.765 | 0.393 | -53.2 | 99.0 | 3 | 0.326 | 0.222 | 28 |
| grid | wakeActive=5 median5=4.0 | 0.280 | 0.802 | 0.723 | 0.401 | -43.1 | 99.5 | 4 | 0.353 | 0.214 | 28 |
| grid | wakeActive=5 | 0.282 | 0.806 | 0.714 | 0.397 | -40.8 | 99.6 | 4 | 0.361 | 0.211 | 28 |
| grid | wakeActive=5 median5=9.0 | 0.284 | 0.808 | 0.712 | 0.394 | -40.1 | 99.6 | 4 | 0.362 | 0.213 | 28 |
| grid | wakeActive=7 median5=2.0 | 0.281 | 0.792 | 0.751 | 0.412 | -48.0 | 99.0 | 3 | 0.340 | 0.226 | 28 |
| grid | wakeActive=7 median5=4.0 | 0.285 | 0.816 | 0.691 | 0.424 | -36.0 | 99.5 | 4 | 0.366 | 0.213 | 28 |
| grid | wakeActive=7 | 0.268 | 0.823 | 0.641 | 0.420 | -31.8 | 99.9 | 3 | 0.359 | 0.189 | 28 |
| grid | wakeActive=7 median5=9.0 | 0.265 | 0.825 | 0.628 | 0.416 | -30.3 | 100.1 | 3 | 0.353 | 0.188 | 28 |
| grid | wakeActive=15 median5=2.0 | 0.278 | 0.821 | 0.666 | 0.437 | -33.8 | 100.1 | 3 | 0.357 | 0.208 | 28 |
| grid | wakeActive=15 median5=4.0 | 0.264 | 0.850 | 0.560 | 0.456 | -16.0 | 101.3 | 4 | 0.378 | 0.171 | 28 |
| grid | wakeActive=15 | 0.258 | 0.860 | 0.524 | 0.457 | -10.4 | 101.5 | 4 | 0.392 | 0.155 | 28 |
| grid | wakeActive=15 median5=9.0 | 0.247 | 0.865 | 0.491 | 0.444 | -6.3 | 101.3 | 4 | 0.379 | 0.147 | 28 |

## Round 2: on top of bridging data gaps

| Group | Variant | κ visible | Sens | Spec | κ raw | TA bias | TA SD | |Onset| > 60 min | κ A | κ B | Kept |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | spec 003 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| combo | mergeMissing=10 | 0.385 | 0.914 | 0.561 | 0.445 | 9.6 | 47.7 | 1 | 0.462 | 0.312 | 28 |
| combo | webster mergeMissing=15 | 0.421 | 0.919 | 0.595 | 0.497 | 9.1 | 41.1 | 1 | 0.497 | 0.355 | 28 |
| combo | raisedHR=3.0 mergeMissing=15 | 0.410 | 0.916 | 0.589 | 0.453 | 11.6 | 42.2 | 1 | 0.477 | 0.350 | 28 |
| combo | minRun=10 mergeMissing=15 | 0.410 | 0.916 | 0.591 | 0.445 | 7.7 | 44.7 | 1 | 0.491 | 0.343 | 28 |
| combo | needsHR mergeMissing=15 | 0.487 | 0.961 | 0.514 | 0.444 | 3.8 | 22.2 | 0 | 0.487 | 0.488 | 28 |
| combo | wakeActive=7 median5=4.0 mergeMissing=15 | 0.386 | 0.891 | 0.643 | 0.424 | -2.9 | 46.9 | 1 | 0.440 | 0.335 | 28 |
| combo | raisedHR=3.0 webster mergeMissing=15 | 0.433 | 0.911 | 0.645 | 0.503 | 4.3 | 42.8 | 1 | 0.491 | 0.381 | 28 |
| combo | minRun=10 webster mergeMissing=15 | 0.432 | 0.913 | 0.637 | 0.497 | 4.6 | 45.4 | 1 | 0.513 | 0.363 | 28 |
| combo | raisedHR=3.0 minRun=10 webster mergeMissing=15 | 0.401 | 0.889 | 0.676 | 0.503 | -6.1 | 68.9 | 2 | 0.506 | 0.316 | 28 |
| combo | wakeActive=7 median5=4.0 webster mergeMissing=15 | 0.410 | 0.885 | 0.707 | 0.468 | -8.6 | 48.5 | 1 | 0.459 | 0.363 | 28 |
| combo | wakeActive=7 median5=4.0 raisedHR=3.0 webster mergeMissing=15 | 0.404 | 0.875 | 0.735 | 0.462 | -13.5 | 50.3 | 1 | 0.443 | 0.365 | 28 |

## Round 3: on top of needing heart rate + bridging gaps

| Group | Variant | κ visible | Sens | Spec | κ raw | TA bias | TA SD | |Onset| > 60 min | κ A | κ B | Kept |
|---|---|---|---|---|---|---|---|---|---|---|---|
| base | spec 003 | 0.274 | 0.843 | 0.597 | 0.445 | -19.9 | 100.5 | 4 | 0.387 | 0.182 | 28 |
| combo | needsHR mergeMissing=15 | 0.487 | 0.961 | 0.514 | 0.444 | 3.8 | 22.2 | 0 | 0.487 | 0.488 | 28 |
| combo | needsHR mergeMissing=5 | 0.413 | 0.929 | 0.546 | 0.444 | -9.8 | 66.1 | 1 | 0.467 | 0.356 | 28 |
| combo | needsHR mergeMissing=10 | 0.475 | 0.952 | 0.539 | 0.444 | -0.8 | 32.0 | 0 | 0.467 | 0.488 | 28 |
| combo | webster needsHR mergeMissing=15 | 0.520 | 0.958 | 0.572 | 0.496 | -2.6 | 21.2 | 0 | 0.501 | 0.542 | 28 |
| combo | raisedHR=3.0 needsHR mergeMissing=15 | 0.507 | 0.954 | 0.569 | 0.453 | -0.8 | 23.1 | 0 | 0.482 | 0.537 | 28 |
| combo | minRun=10 needsHR mergeMissing=15 | 0.502 | 0.954 | 0.565 | 0.444 | -4.0 | 26.4 | 0 | 0.489 | 0.516 | 28 |
| combo | raisedHR=3.0 webster needsHR mergeMissing=15 | 0.530 | 0.950 | 0.624 | 0.502 | -7.5 | 22.2 | 0 | 0.494 | 0.573 | 28 |
| combo | minRun=10 webster needsHR mergeMissing=15 | 0.525 | 0.951 | 0.611 | 0.496 | -6.7 | 27.1 | 0 | 0.511 | 0.541 | 28 |
| combo | wakeActive=7 median5=4.0 webster needsHR mergeMissing=15 | 0.487 | 0.922 | 0.686 | 0.467 | -20.6 | 29.1 | 0 | 0.456 | 0.524 | 28 |

## Owner's fixture nights (Strap turn at 2°)

```
## Strap Night-2026-10-29
spec 003	onset 2026-10-28T23:48:00Z	wake 2026-10-29T04:50:00Z	asleep 267 min	bouts 17
needsHR mergeMissing=15	onset 2026-10-28T23:48:00Z	wake 2026-10-29T04:50:00Z	asleep 267 min	bouts 17
webster needsHR mergeMissing=15	onset 2026-10-28T23:52:00Z	wake 2026-10-29T04:50:00Z	asleep 260 min	bouts 17
raisedHR=3.0 webster needsHR mergeMissing=15	onset 2026-10-28T23:52:00Z	wake 2026-10-29T04:50:00Z	asleep 252 min	bouts 17

## Strap Night-2026-10-30
spec 003	onset 2026-10-29T21:05:00Z	wake 2026-10-30T03:42:00Z	asleep 352 min	bouts 21
needsHR mergeMissing=15	onset 2026-10-29T21:05:00Z	wake 2026-10-30T03:42:00Z	asleep 352 min	bouts 21
webster needsHR mergeMissing=15	onset 2026-10-29T21:09:00Z	wake 2026-10-30T03:23:00Z	asleep 332 min	bouts 19
raisedHR=3.0 webster needsHR mergeMissing=15	onset 2026-10-29T21:09:00Z	wake 2026-10-30T03:23:00Z	asleep 329 min	bouts 19
```
