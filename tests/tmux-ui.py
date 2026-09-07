"""使用真实 PTY/fzf/tmux 验证方向键选择、新建、挂起后返回及退出。"""
import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time

command, tmux = sys.argv[1:]
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 32, 100, 0, 0))
env = dict(os.environ, TERM='xterm-256color', FZF_DEFAULT_OPTS='', FZF_DEFAULT_OPTS_FILE='')
env.pop('TMUX', None)
process = subprocess.Popen([command], stdin=slave, stdout=slave, stderr=slave,
                           env=env, start_new_session=True,
                           preexec_fn=lambda: fcntl.ioctl(slave, termios.TIOCSCTTY, 0))
os.close(slave)
buffer = b''

def wait_for(text):
    global buffer
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if text.encode() in buffer:
            buffer = b''
            return
        if select.select([master], [], [], 0.1)[0]:
            data = os.read(master, 65536)
            if b'\x1b[6n' in data:
                os.write(master, b'\x1b[1;1R')
            buffer += data
    raise AssertionError('PTY did not show: ' + text)

def send(data):
    os.write(master, data)

def drain():
    global buffer
    while select.select([master], [], [], 0.2)[0]:
        os.read(master, 65536)
    buffer = b''

try:
    # 初始仅有 smoke 测试保留的 dev-extra 会话，向下选择后回车进入。
    wait_for('dev-extra')
    send(b'\x1b[B\r')
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        clients = subprocess.check_output([tmux, 'list-clients', '-F', '#{session_name}'])
        if b'dev-extra' in clients:
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Down + Enter did not attach dev-extra')
    drain()
    subprocess.check_call([tmux, 'detach-client', '-s', '=dev-extra'])
    wait_for('新建会话')
    send(b'\r')
    wait_for('新会话名称')
    send(b'ui-created\r')
    wait_for('工作目录')
    send(b'\r')
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        clients = subprocess.check_output([tmux, 'list-clients', '-F', '#{session_name}'])
        if b'ui-created' in clients:
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Create did not attach the new session')
    drain()
    subprocess.check_call([tmux, 'detach-client', '-s', '=ui-created'])
    wait_for('新建会话')
    send(b'0')
    assert process.wait(timeout=5) == 0
    print('PASS: real PTY arrow selection, attach, create, detach, return')
finally:
    if process.poll() is None:
        process.kill()
        process.wait()
    os.close(master)
