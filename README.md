# Netconnect_ha

CA UIM Net_connect High availability

This probe bring high availability for net_connect probe. It can be useful if you split your pings profiles between multiple net_connect (On the active & passive hub for example). So, if the active hub go down you are not going to loose any pings monitoring.

This probe work like the HA probe. It was created with the objective of managing a single node. But this time you have to install the probe on both hub (bi-directionnal HA).

You have to be vigilant if you mix this probe with any kind of net_connect provisionning mechanism (can generate collision between them). I'm working on a way to manage this (AKA daemon probe with callback).

# Documentation

Find the documentation [Here](https://github.com/fraxken/netconnect_ha/wiki)

# Requirement 

This probe require [perluim 4.2](https://github.com/fraxken/perluim) or higher.

> **Warning** Perluim 4.2 is under development. 

# Roadmap v1.1 (LTS)

- [x] Clone group.
- [x] Clone profiles services.
- [x] Avoid collision when we merge cfg between them.
- [x] Create two distincts version ( timed probe & daemon probe ).
- [x] First API documentation for netconnect_ha core class.

> **Wait for perluim 4.2 release**
