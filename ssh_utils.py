import paramiko
import yaml
import getpass
import os, sys

class ssh_utilities:
  def __init__(self,sid):
    if not sid:
      self.sid = 'fake'
    else:
      self.sid = sid
    self._instance = None
    self._ssh_client = None


  def read_input(self):
    username = getpass.getuser()
    op_dir = os.path.dirname(sys.argv[0])
    if op_dir == '':
      op_dir = os.getcwd()
    # Read YAML file
    with open(op_dir+"/ssh_config.yaml", 'r') as stream:
      data_loaded = yaml.safe_load(stream)
    file_list = data_loaded[username]
    self.xhost = file_list['host']
    self.xuser = file_list['user']
    self.xssh_key_filepath = file_list['ssh_key_filepath']
    self.xremote_path = file_list['remote_path']
    self.xlocal_file_directory = os.path.join(file_list['local_file_directory'],self.sid)
    self.xhost_key_file = file_list['host_key_file']
    self.xlocal_file_directory = os.path.join(file_list['local_file_directory'],self.sid)
    self.xfiles = file_list['file_type']

  def get_ssh_client(self, host, key_file, host_key_file, uname):
    if not self._ssh_client:
      if not key_file:
        iobject = IObject()
        key_file = iobject.get_filename('Path to OpenSSH Key file')
      self._pkey = paramiko.RSAKey.from_private_key_file(key_file)
      self._ssh_client = paramiko.SSHClient()
      self._ssh_client.load_system_host_keys()
      self._ssh_client.load_host_keys(os.path.expanduser(host_key_file))
      self._ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
      self._ssh_client.connect(host, username=uname, pkey=self._pkey)
    return self._ssh_client 
