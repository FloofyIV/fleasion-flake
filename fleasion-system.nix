{ self }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.fleasion-system;

  defaultFleasionExec = "${self.packages.${pkgs.system}.default}/bin/fleasion-src";
in
{
  options.services.fleasion-system = {
    enable = mkEnableOption "Fleasion system-level configuration (hosts + polkit)";

    extraHosts = mkOption {
      type = types.lines;
      default = ''
        127.0.0.1 assetdelivery.roblox.com
        127.0.0.1 contentdelivery.roblox.com
        127.0.0.1 fts.rbxcdn.com
        127.0.0.1 gamejoin.roblox.com
      '';
    };

    fleasionExecPath = mkOption {
      type = types.str;
      default = defaultFleasionExec;
    };
  };

  config = mkIf cfg.enable {
    networking.extraHosts = cfg.extraHosts;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            action.lookup("program") == "${cfg.fleasionExecPath}" &&
            subject.active && subject.local) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
