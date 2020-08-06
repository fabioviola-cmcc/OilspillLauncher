#!/usr/bin/python3

# requirements
import os, sys, getopt
import getpass
from ssh_utils import ssh_utilities


# ex_rem_cmd function
def ex_rem_cmd(ssh_conn, cmd):

  # execute cmd on SSH connection
  stdin,stdout,stderr = ssh_conn.exec_command(cmd)  
  print("[finalize.py] -- Executing on SSH: %s" % cmd)
  print('[finalize.py] -- Output:')
  print(stdout.read().decode('ascii').strip("\n"))
  print('[finalize.py] -- Errors:')
  print(stderr.read().decode('ascii').strip("\n"))
  stdout.channel.recv_exit_status()
  print("[finalize.py] -- Exit status: %s" % stdout.channel.recv_exit_status())


# main function
def main(argv):

  # parse command line arguments
  try:
    opts, args = getopt.getopt(argv,"h:s",["help","sim_id="])
  except getopt.GetoptError:
    print 'finalize.py -s <Simulation_ID>'
    sys.exit(2)  
  for opt, arg in opts:
    if opt in ('-h', '--help'):
      print 'finalize.py -s <Simulation_ID>'
      sys.exit()
    elif opt in ("-s", "--sim_id"):
      s_id = arg

  # debug print
  print("[finalize.py] -- Finalizing simulation %s" % s_id)

  # create an instance of class ssh_utilities
  ssh1 = ssh_utilities(s_id)
  ssh1.read_input()

  # get the ssh client
  cl = ssh1.get_ssh_client(ssh1.xhost, ssh1.xssh_key_filepath, ssh1.xhost_key_file, ssh1.xuser)

  # create remote directories based on the path in the yaml file
  cmd1 = 'mkdir -p ' + os.path.join(ssh1.xremote_path, s_id, 'in_sim') 
  cmd2 = 'mkdir -p ' + os.path.join(ssh1.xremote_path, s_id, 'in_env') 
  ex_rem_cmd(cl, cmd1)
  ex_rem_cmd(cl, cmd2)

  # open an ftp client and upload output files
  ftp_client = cl.open_sftp()
  uploads = [ ftp_client.put(os.path.join(ssh1.xlocal_file_directory,file), os.path.join(ssh1.xremote_path, s_id, 'in_sim',file)) for file in ssh1.xfiles]
  ftp_client.close()

  # final commands for map server
  cmd3 = "python " + os.path.join(ssh1.xremote_path, '..' , 'fromConfini2Symlink.py')+ " -i " + os.path.join(ssh1.xremote_path, s_id, 'in_sim','conf.ini')
  cmd4 = "/bin/bash " + os.path.join(ssh1.xremote_path, 'run4Mapserver.sh') + ' ' + s_id
  ex_rem_cmd(cl, cmd3)
  ex_rem_cmd(cl, cmd4)


# main
if __name__ == "__main__":
  main(sys.argv[1:])
