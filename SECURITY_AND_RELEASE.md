# Security & release checklist

## 1) What is in the old git history (checked)
Searched all commits: the Ed25519 **private key was never committed**
(`license_keys.txt`, `*.lic`, `*.db`, keystores and `key.properties` have no
history). Only these files were tracked before the cleanup:
- `activation_code.txt` - an old demo activation code (7 days, device-bound)
- `issued_demos.txt` - device fingerprints of demo machines

So no key rotation is required because of the history. Cleaning it is
optional (the repo is public, so these two files stay visible in old
commits). If you want it anyway, back up first, then:
```
pip install git-filter-repo
git filter-repo --invert-paths --path activation_code.txt --path issued_demos.txt
git push --force --all   # then ask collaborators to re-clone
```
Do this before enabling branch protection on `main` (protection blocks
force-push), or temporarily allow it. If the private key is ever stored in
the repo by mistake, rotate it: regenerate the Ed25519 pair, update
`_publicKeyBase64` in license_service.dart and re-issue all licenses.

## 2) Android signing
`./tools/create_keystore.sh` then `flutter build appbundle --release`.
Back up the .jks and its passwords. Never commit them (already git-ignored).

## 3) Accountant review (values are editable in Rules page, defaults only)
- Personal exemption (default 20,000 EGP/year)
- Insurance min/max insurable wage, employee 11% / employer 18.75% (change yearly)
- Tax brackets
- Whether employee insurance is deducted from the tax base

## 4) Known limits
- Offline licensing cannot be made unbreakable: the HMAC seal key is derived
  from constants inside the app. The Ed25519 signature + device binding is the
  real protection; the local demo marker is mirrored to a sealed file outside
  the database, but a determined user can still reset it.
- Web build is disabled unless built with `--dart-define=ALLOW_WEB=true`.
