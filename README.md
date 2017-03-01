# netconnect_ha
CA UIM Net_connect High availability

This probe has been created to do the same job as HA probe but for net_connect. You put the probe on one hub and you configure `nim_addr` in the configuration file (the distant hub you need to synchronise).

You can put the probe on both hub to create bi-directionnal HA.

The probe only support HA for ping profiles (see roadmap for group etc..).

# Requirement 

This probe require [perluim 4.2](https://github.com/fraxken/perluim) or higher.

> **Warning** Perluim 4.2 is under development. 

# Roadmap v1.1

- Clone group.
