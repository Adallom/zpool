[![Build Status](https://secure.travis-ci.org/marthag8/zpool.png)](http://travis-ci.org/marthag8/zpool)

Description
===========

Lightweight resource and provider to manage Solaris zpools. 

Currently, just creates or destroys simple zpools.


Requirements
============

Solaris, zpool.

Attributes
==========

    disks - An "array" of disks to put in the pool. These disks will be striped across in a flat layout (essentially a RAID-0 configuration).

    entities - A "hash" of vdev definitions to compose the pool's tree. The pool will stripe across the entities (so essentially a RAID 10 or RAID 50/60 depending on on the type of entities that would compose your pool). The hash can contain sub-hashes that define sub-vdevs (see the "log" example below). While abiding to the regular Zpool rules, entities can include: "mirror", "raidX", "log" and "cache".

    force - A "true" or "false" declaration to toggle the "-f" (force) flag, when invoking the Zpool command. Using this Zpool option will override warning like "disk had another use", and "Mismatched Replication Levels". Default is "false", and it is strongly recommended to use sparingly and with caution.

    graceful - A "true" or "false" declaration to toggle the behavior of the provider in case a sanity check fails. The default (true) is to try and gracefully move on to the next task. Passing "false" to this toggle, will cause a Chef halt if such an event is encountered.

Usage
=====
You may use both the "disks" notation and the "entities" notation, but keep in mind that in such a case you will mostly only want to use "entities" to define "log" and "cache" devices. This is mainly because, from what I've seen, crating a flat RAID0 with a RAID10/50/60 at the same level, is frowned upon by Zpool (you would have to be forceful about it, if you really really wanna zigazig ha).

You may use "devices" a.k.a "disks" by either their full path (i.e. "/dev/xvdc") or just their short notation (i.e. "xvdc"), the provider will strip them all down to just the short notation for you. It is also possible to use "files" as "devices", if you really need to (though this is recommended for development use only).

Note that while some sanity checks are performed, this provider will by no means protect you against all Zpool miss configurations requests. Its not that it would succeed in creating them, it would just won't give a "nice" chef error about it.

To use the "disks" notation, simply feed an array to the provider:

    zpool "test" do
      disks [ "c0t2d0s0", "c0t3d0s0" ]
    end
  
To use the "entities" feature, in an attribute used by your cookbook, define the variable that holds the entities. In the example below I chose "ZpoolTree":

	"ZpoolTree" : {
                  "mirror" : ["/dev/xvdb","xvdc"],
                  "mirror" : ["xvdh","/dev/xvde"],
                  "mirror" : ["xvdf","/dev/xvdl"],
                  "cache" : ["xvdm","/dev/xvdn"],
                  "log" : {
                    "mirror": ["xvdi", "xvdk"]
                  }
                }

	zpool "LennySol00" do
      entities node['ZpoolTree']
    end


It is also possible to destroy a pool:

    zpool "test2" do
        action :destroy
    end
