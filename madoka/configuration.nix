# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  znap = fs: {
    name = "rpool/${fs}";
    value = {
      plan = "1d=>15min,3d=>1h";
      destinations.tsugumi = {
        host = "znapzend@brage.info";
        dataset = "stash/backups/${config.networking.hostName}/${fs}";
        plan = "1w=>1h,12w=>1d";
      };
    };
  };
  znapz = filesystems: builtins.listToAttrs (builtins.map znap filesystems);
in

{
  imports = [
    ../modules
    ./hardware-configuration.nix
    ./minecraft.nix
    #./mediawiki.nix
  ];

  # F#&$*ng Spectre
  #boot.kernelParams = [
  #  "pti=off"
  #  "spectre_v2=off"
  #  "l1tf=off"
  #  "nospec_store_bypass_disable"
  #  "no_stf_barrier"
  #];
  
  ## Boot ##
  # Start up if at all possible.
  systemd.enableEmergencyMode = false;

  security.pam.loginLimits = [{
    domain = "minecraft";
    type = "-";
    item = "memlock";
    value = "16777216";
  }];

  ## Backups ##
  services.znapzend = {
    enable = true;
    autoCreation = true;
    pure = true;
    zetup = znapz [
      "home"
      "home/minecraft"
      "home/minecraft/erisia"
      "home/minecraft/incognito"
      "home/bloxgate"
      "home/darqen27"
      "home/david"
      "home/dusk"
      "home/jmc"
      "home/kim"
      "home/lucca"
      "home/luke"
      "home/mei"
      "home/prospector"
      "home/simplynoire"
      "home/svein"
      "home/svein/win"
      "home/vindex"
      "home/will"
      "home/xgas"
    ];
  };

  ## Networking ##
  networking.hostName = "madoka";
  networking.hostId = "8425e349";
  # Doesn't work due to missing interface specification.
  #networking.defaultGateway6 = "fe80::1";
  networking.localCommands = ''
    ${pkgs.nettools}/bin/route -6 add default gw fe80::1 dev eth0 || true
  '';
  networking.nameservers = [ "8.8.8.8" "8.8.4.4" ];
  networking.interfaces.eth0 = {
    ipv6.addresses = [{
      address = "2a01:4f9:2b:808::1";
      prefixLength = 64;
    }];
  };
  networking.firewall = {
    allowPing = true;
    allowedTCPPorts = [ 
      80 443  # Web-server
      25565 25566 25567  # Minecraft
      4000  # ZNC
      12345  # JMC's ZNC
    ];
    allowedUDPPorts = [
      34197  # Factorio
      10401  # Wireguard
    ];
  };
  #networking.nat = {
  #  enable = true;  # For mediawiki.
  #  externalIP = "138.201.133.39";
  #  externalInterface = "eth0";
  #  internalInterfaces = [ "ve-eln-wiki" ];
  #};

  # Wireguard link between my machines
  networking.wireguard = {
    interfaces.wg0 = {
      ips = [ "10.40.0.2/24" ];
      listenPort = 10401;
      peers = [
        # Tsugumi
        {
          allowedIPs = [ "10.40.0.1/32" ];
          endpoint = "madoka.brage.info:10401";
          persistentKeepalive = 30;
          publicKey = "H70HeHNGcA5HHhL2vMetsVj5CP7M3Pd/uI8yKDHN/hM=";
        }
        # Saya
        {
          allowedIPs = [ "10.40.0.3/32" ];
          persistentKeepalive = 30;
          publicKey = "VcQ9no2+2hSTa9BO2fEpickKC50ibWp5uo0HrNBFmk8=";
        }
      ];
      privateKeyFile = "/secrets/wg.key";
    };
  };


  users.include = [
    "mei" "einsig" "prospector" "minecraft" "bloxgate" "buizerd"
    "darqen27" "david" "jmc" "kim" "luke" "simplynoire" "vindex"
    "xgas" "will" "lucca" "dusk"
  ];

  ## Webserver ##
  services.nginx = {
    package = pkgs.nginxMainline.override {
#      modules = with pkgs.nginxModules; [ njs dav moreheaders ];
    };
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    sslDhparam = ./nginx/dhparams.pem;
    statusPage = true;
    appendHttpConfig = ''
      add_header Strict-Transport-Security "max-age=31536000; includeSubdomains";
      add_header X-Clacks-Overhead "GNU Terry Pratchett";
      autoindex on;
      etag on;

      # Fallback config for Erisia
      upstream erisia {
        server 127.0.0.1:8123;
# server unix:/home/minecraft/erisia/staticmap.sock backup;
      }
      # server {
      #   listen unix:/home/minecraft/erisia/staticmap.sock;
      #   location / {
      #     root /home/minecraft/erisia/dynmap/web;
      #   }
      # }
      # Ditto, Incognito.
      # TODO: Factor this. Perhaps send a PR or two.
      upstream incognito {
        server 127.0.0.1:8124;
  # server unix:/home/minecraft/incognito/staticmap.sock backup;
      }
      # server {
      #   listen unix:/home/minecraft/incognito/staticmap.sock;
      #   location / {
      #     root /home/minecraft/incognito/dynmap/web;
      #   }
      # }
      upstream tppi {
        server 127.0.0.1:8126;
        # server unix:/home/tppi/server/staticmap.sock backup;
      }
      # server {
      #   listen unix:/home/tppi/server/staticmap.sock;
      #   location / {
      #     root /home/tppi/server/dynmap/web;
      #   }
      # }
      
    '';
    virtualHosts = let
      base = locations: {
        forceSSL = true;
        enableACME = true;
        inherit locations;
      };
      proxy = port: base {
        "/".proxyPass = "http://127.0.0.1:" + toString(port) + "/";
      };
      root = dir: base {
        "/".root = dir;
      };
      minecraft = {
        root = "/home/minecraft/web";
        tryFiles = "\$uri \$uri/ =404";
        extraConfig = ''
          add_header Cache-Control "public";
          expires 1h;
        '';
      };
    in {
      "madoka.brage.info" = base {
        "/" = minecraft;
        "/warmroast".proxyPass = "http://127.0.0.1:23000/";
        "/baughn".extraConfig = "alias /home/svein/web;";
        "/tppi".extraConfig = "alias /home/tppi/web;";
      } // { default = true; };
      "status.brage.info" = proxy 9090;
      "grafana.brage.info" = proxy 3000;
      "tppi.brage.info" = root "/home/tppi/web";
      "alertmanager.brage.info" = proxy 9093;
      "map.brage.info" = base { "/".proxyPass = "http://erisia"; };
      "incognito.brage.info" = base { "/".proxyPass = "http://incognito"; };
      "tppi-map.brage.info" = base { "/".proxyPass = "http://tppi"; };
      "cache.brage.info" = root "/home/svein/web/cache";
      "znc.brage.info" = base { 
         "/" = {
           proxyPass = "https://127.0.0.1:4000";
           extraConfig = "proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;";
         };
      };
      "quest.brage.info" = proxy 2222;
      "warmroast.brage.info" = proxy 23000;
      "hydra.brage.info" = proxy 3001;
    };
  };
}
