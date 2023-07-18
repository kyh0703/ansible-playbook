from ast import literal_eval
import yaml
import argparse

with open('./cluster.yml') as f:
    cluster_data = yaml.load(f, Loader=yaml.FullLoader)

def make_master(host, address):
    master = dict()
    master["address"] = host
    master["internal_address"] = address
    master["user"] = "rke"
    master["port"] = 22
    master["role"] = ["controlplane", "etcd"]
    master["docker_socket"] = "/var/run/docker.sock"
    master["ssh_key_path"] = "~/.ssh/id_rsa"
    cluster_data["nodes"].append(master)

def make_worker(host, address):
    worker = dict()
    worker["address"] = host
    worker["internal_address"] = address
    worker["user"] = "rke"
    worker["port"] = 22
    worker["role"] = ["worker"]
    worker["docker_socket"] = "/var/run/docker.sock"
    worker["ssh_key_path"] = "~/.ssh/id_rsa"
    cluster_data["nodes"].append(worker)

parser = argparse.ArgumentParser(prog="make rke cluster.yaml")
parser.add_argument('--host', help='rke node hostname')
parser.add_argument('--address', help='rke node real ip address')
parser.add_argument('--role', help='rke node role')
args = parser.parse_args()
print(args)

if "master" in args.role:
    make_master(args.host, args.address)
elif "worker" in args.role:
    make_worker(args.host, args.address)

with open("./cluster.yml", "w") as fw:
    yaml.dump(cluster_data, fw)