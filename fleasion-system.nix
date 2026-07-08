{ self }:
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.fleasion-system;

  polkitData = self._fleasionPolkit.${pkgs.system};

  defaultProgram = "${polkitData.pythonEnv}/bin/python";
  defaultScriptMatch = polkitData.helperDaemonScript;
in
{
  options.services.fleasion-system = {
    enable = mkEnableOption "Fleasion system-level configuration (hosts + polkit)";

    extraHosts = mkOption {
      type = types.lines;
      default = ''
        127.0.0.1 a.com
        127.0.0.1 b.com
        127.0.0.1 c.com
        127.0.0.1 d.com
      '';
    };

    fleasionProgram = mkOption {
      type = types.str;
      default = defaultProgram;
    };

    fleasionScriptMatch = mkOption {
      type = types.str;
      default = defaultScriptMatch;
    };
  };

  config = mkIf cfg.enable {
    networking.extraHosts = cfg.extraHosts;

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        var cmd = action.lookup("command_line") || "";
        if (action.id == "org.freedesktop.policykit.exec" &&
            action.lookup("program") == "${cfg.fleasionProgram}" &&
            cmd.indexOf("${cfg.fleasionScriptMatch}") !== -1 &&
            subject.active && subject.local) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}

