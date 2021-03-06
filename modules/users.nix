{ lib, config, ... }:

let
  sshKeys = import ./sshKeys.nix;
  users = {
    svein = {
      uid = 1000;
      extraGroups = [ "wheel" "wireshark" "systemd-journal" "disnix" "networkmanager" ];
    };
    bloxgate.uid = 1001;
    kim.uid = 1002;
    jmc = {
      uid = 1003;
      shell = "/run/current-system/sw/bin/bash";
    };
    david.uid = 1005;
    luke.uid = 1006;
    darqen27.uid = 1007;
    simplynoire.uid = 1009;
    buizerd.uid = 1010;
    vindex.uid = 1011;
    xgas.uid = 1012;
    einsig.uid = 1014;
    prospector.uid = 1015;
    mei.uid = 1017;
    minecraft = {
      uid = 1018;
      openssh.authorizedKeys.keys = builtins.concatLists (lib.attrValues sshKeys);
    };
    will.uid = 1050;
    pl.uid = 1051;
    aquagon.uid = 1052;
    znapzend = {
      uid = 1054;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAW37vjjfhK1hBwHO6Ja4TRuonXchlLVIYnA4Px9hTYD svein@madoka.brage.info"
      ] ++ sshKeys.svein;
    };
    lucca.uid = 1055;
    dusk.uid = 1056;
    # Next free ID: 1057
    anne.uid = 1100;
  };
  includeUser = username: ({
    isNormalUser = true;
    openssh.authorizedKeys.keys = sshKeys.${username} or [];
  } // users.${username});
in

with lib; {
  options = {
    users.include = mkOption {
      type = types.listOf types.str;
      description = "Users to include on this system";
      default = [];
    };
  };

  config = {
    users.users = lib.genAttrs config.users.include includeUser;
  };
}
