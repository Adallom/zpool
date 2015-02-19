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

Usage
=====
You may use both the "disks" notation or the "entities" notation, but keep in mind that in such a case you will mostly only be able to use "entities" to define "log" and "cache" devices (mainly because, from what i've seen, crating a flat RAID0 with a RAID10/50/60 at the same level is simply not supported by Zpool).
Note that while some sanity checks are performed, this provider will by no means protect you against all Zpool miss configurations requests. Its not that it would succeed in creating them, it would just wont give a "nice" chef error about it.

To you the "disks" notation, simply feed an array to the provider:

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

	zpool "IchigoBankai" do
      entities node['ZpoolTree']
    end


It is also possible to destroy a pool:

    zpool "test2" do
        action :destroy
    end
