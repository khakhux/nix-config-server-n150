I'm doing a  sudo nixos-rebuild switch --flake ~/nix-config-server-n150#"$host"

and getting the error
error: path '/nix/store/xvapcm0q7jwk8lib0yz3ikvxshd81gr5-linux-6.12.63-modules-shrunk/lib' is not in the Nix store

path '/nix/store/...-linux-6.12.63-modules-shrunk/lib' exists

this happens after adding flake.nix in a nixos without flakes enabled

---

Yes — once flakes are enabled and applied, that’s exactly the command you should be using:

```bash
sudo nixos-rebuild switch --flake ~/nix-config-server-n150#"$host"
```

---

## ✔️ What changed after enabling flakes

Now Nix will:

* Evaluate your system via `flake.nix`
* Use pinned inputs (no more channel drift)
* Build exactly the configuration defined in `nixosConfigurations."<host>"`

---

## 🔍 Quick sanity check

Make sure your flake actually defines that host:

```nix
outputs = { self, nixpkgs, ... }: {
  nixosConfigurations.myHost = nixpkgs.lib.nixosSystem {
    # ...
  };
};
```

Then `$host` must match:

```bash
echo $host
```

If it doesn’t match, you’ll get errors like “attribute not found”.

---

## 💡 Useful variations

* Rebuild and show more logs:

  ```bash
  sudo nixos-rebuild switch --flake ~/nix-config-server-n150#"$host" --show-trace
  ```

* Test without switching:

  ```bash
  sudo nixos-rebuild test --flake ~/nix-config-server-n150#"$host"
  ```

* Boot into it next reboot:

  ```bash
  sudo nixos-rebuild boot --flake ~/nix-config-server-n150#"$host"
  ```

---

## ⚠️ Common gotcha (worth checking)

If you *still* see weird store/path errors after this, it’s usually because:

* You previously built parts of the system **without flakes**
* Old generations are still referenced

In that case:

```bash
sudo nix-collect-garbage -d
```

and rebuild again.

---

If you hit another error after switching to flakes, paste it — flake setups are strict, but once stable, they’re much more predictable.
