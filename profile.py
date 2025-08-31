"""This profile sets up a simple NFS server and a network of clients. The NFS server uses
a long term dataset that is persistent across experiments. In order to use this profile,
you will need to create your own dataset and use that instead of the demonstration 
dataset below. If you do not need persistant storage, we have another profile that
uses temporary storage (removed when your experiment ends) that you can use. 

Instructions:
Click on any node in the topology and choose the `shell` menu item. Your shared NFS directory is mounted at `/nfs` on all nodes."""

import geni.portal as portal
import geni.rspec.pg as pg
import geni.rspec.emulab as emulab
import geni.rspec.igext as igext

pc = portal.Context()
request = pc.makeRequestRSpec()

# nodes
nfs = request.RawPC('nfs'); nfs.hardware_type = 'm510'; if0 = nfs.addInterface('iface-exp')
node_1 = request.RawPC('node-1'); node_1.hardware_type = 'm510'; if1 = node_1.addInterface('iface-exp')
node_2 = request.RawPC('node-2'); node_2.hardware_type = 'm510'; if2 = node_2.addInterface('iface-exp')

site_cm = "urn:publicid:IDN+utah.cloudlab.us+authority+cm"
img = "urn:publicid:IDN+utah.cloudlab.us+image+emulab-ops//UBUNTU22-64-STD"
for n in (nfs, node_1, node_2):
    n.component_manager_id = site_cm
    n.disk_image = img

# LAN for NFS
lan = pg.LAN('nfs-lan')
lan.best_effort = True
lan.vlan_tagging = True
lan.link_multiplexing = True

if0.addAddress(pg.IPv4Address("10.0.0.1", "255.255.255.0"))
if1.addAddress(pg.IPv4Address("10.0.0.2", "255.255.255.0"))
if2.addAddress(pg.IPv4Address("10.0.0.3", "255.255.255.0"))
lan.addInterface(if0); lan.addInterface(if1); lan.addInterface(if2)
request.addResource(lan)

# dataset on server only, mounted at /nfs
URN = "urn:publicid:IDN+utah.cloudlab.us:rdmaanns-pg0+ltdataset+ANN_dataset"
MP  = "/nfs"

rbs = request.RemoteBlockstore("dsnode", MP)
rbs.dataset = URN

ds_if = nfs.addInterface("iface-ds")
ds_link = request.Link("dslink")
ds_link.addInterface(ds_if)
ds_link.addInterface(rbs.interface)
ds_link.best_effort = True
ds_link.vlan_tagging = True
ds_link.link_multiplexing = True

# run official init scripts
nfs.addService(pg.Execute(shell="sh", command="sudo /bin/bash /local/repository/nfs-server.sh"))
for n in (node_1, node_2):
    n.addService(pg.Execute(shell="sh", command="sudo /bin/bash /local/repository/nfs-client.sh"))

pc.printRequestRSpec(request)
