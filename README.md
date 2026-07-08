add to configuration.nix:

```
networking.extraHosts =
  ''
    127.0.0.1 assetdelivery.roblox.com
    127.0.0.1 contentdelivery.roblox.com
    127.0.0.1 fts.rbxcdn.com
    127.0.0.1 gamejoin.roblox.com
  '';
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.policykit.exec" &&
          subject.user === "add your username here!!") { # <-- make sure to do this
        return polkit.Result.YES;
      }
    });
  '';
```
