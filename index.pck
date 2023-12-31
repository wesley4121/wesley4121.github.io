GDPC                                                                                         T   res://.godot/exported/133200997/export-23186f883164cbeaffe487e6aecd5af8-lobby.scn   �+      �
      �T�է�pY���\    T   res://.godot/exported/133200997/export-71b5ab2463e97738099ce6f4a2aa61d7-paddle.scn  �7             M5U~�b,�[dR�vo    P   res://.godot/exported/133200997/export-84d343c4ab84bd4c0000a57675c7d9cd-pong.scn=      G	      71�q�ו��<}*��    P   res://.godot/exported/133200997/export-f46c71a9b7f0892a5bf2bd9cf0943875-ball.scn�      �      �м�a��G3�D��    ,   res://.godot/global_script_class_cache.cfg  `I             ��Р�8���8~$}P�    D   res://.godot/imported/ball.png-9a4ca347acb7532f6ae347744a6b04f7.ctex�      b       �v��6��OR�6-��    H   res://.godot/imported/icon.webp-e94f9a68b0f625a567a797079e4d325f.ctex   �#      �      i�'9�$!�+{	jw��    H   res://.godot/imported/paddle.png-0e798fb0912613386507c9904d5cc01a.ctex  �6      h       =;b��:����`萭    L   res://.godot/imported/separator.png-f981c8489b9148e2e1dc63398273da74.ctex   `F      j       Hy���1�l�.��n�       res://.godot/uid_cache.bin  �P      w      M�t��L�g�5lH�d       res://ball.png.import   0      �       5��� MKҰ������       res://ball.tscn.remap   �G      a       ;�#$�#ui�+�9KY)       res://icon.webp �I      "      ��ʤ��\8�����4.       res://icon.webp.import  +      �       L�K��W����Yl	��       res://lobby.tscn.remap  H      b       �ې�=3���!��       res://logic/ball.gd         i      �6�1e�cb�HE�#       res://logic/lobby.gdp      �       N��R�f�眖�Ӫ�       res://logic/paddle.gd   0      N      ��.�S��*£���ŷ       res://logic/pong.gd �      2      �T���J'_�_��J�g       res://paddle.png.import  7      �       V�0���PV:��#�R�       res://paddle.tscn.remap �H      c       y����}h)��{��       res://pong.tscn.remap   �H      a       �K(о������h>�       res://project.binary0R      A      ���	W!2�]�W�t0       res://separator.png.import  �F      �       �eM��������ɕ���    extends Area2D

const DEFAULT_SPEED = 100

var direction = Vector2.LEFT
var stopped = false
var _speed = DEFAULT_SPEED

@onready var _screen_size = get_viewport_rect().size

func _process(delta):
	_speed += delta
	# Ball will move normally for both players,
	# even if it's sightly out of sync between them,
	# so each player sees the motion as smooth and not jerky.
	if not stopped:
		translate(_speed * delta * direction)

	# Check screen bounds to make ball bounce.
	var ball_pos = position
	if (ball_pos.y < 0 and direction.y < 0) or (ball_pos.y > _screen_size.y and direction.y > 0):
		direction.y = -direction.y

	if is_multiplayer_authority():
		# Only the master will decide when the ball is out in
		# the left side (it's own side). This makes the game
		# playable even if latency is high and ball is going
		# fast. Otherwise ball might be out in the other
		# player's screen but not this one.
		if ball_pos.x < 0:
			get_parent().update_score.rpc(false)
			_reset_ball.rpc(false)
	else:
		# Only the puppet will decide when the ball is out in
		# the right side, which is it's own side. This makes
		# the game playable even if latency is high and ball
		# is going fast. Otherwise ball might be out in the
		# other player's screen but not this one.
		if ball_pos.x > _screen_size.x:
			get_parent().update_score.rpc(true)
			_reset_ball.rpc(true)


@rpc("any_peer", "call_local")
func bounce(left, random):
	# Using sync because both players can make it bounce.
	if left:
		direction.x = abs(direction.x)
	else:
		direction.x = -abs(direction.x)

	_speed *= 1.1
	direction.y = random * 2.0 - 1
	direction = direction.normalized()


@rpc("any_peer", "call_local")
func stop():
	stopped = true


@rpc("any_peer", "call_local")
func _reset_ball(for_left):
	position = _screen_size / 2
	if for_left:
		direction = Vector2.LEFT
	else:
		direction = Vector2.RIGHT
	_speed = DEFAULT_SPEED
>뻆$eextends Control

# Default game server port. Can be any number between 1024 and 49151.
# Not present on the list of registered or common ports as of December 2022:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 8910

@onready var address = $Address
@onready var host_button = $HostButton
@onready var join_button = $JoinButton
@onready var status_ok = $StatusOk
@onready var status_fail = $StatusFail
@onready var port_forward_label = $PortForward
@onready var find_public_ip_button = $FindPublicIP

var peer = null

func _ready():
	# Connect all the callbacks related to networking.
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	multiplayer.connected_to_server.connect(self._connected_ok)
	multiplayer.connection_failed.connect(self._connected_fail)
	multiplayer.server_disconnected.connect(self._server_disconnected)

#### Network callbacks from SceneTree ####

# Callback from SceneTree.
func _player_connected(_id):
	# Someone connected, start the game!
	var pong = load("res://pong.tscn").instantiate()
	# Connect deferred so we can safely erase it from the callback.
	pong.game_finished.connect(self._end_game, CONNECT_DEFERRED)

	get_tree().get_root().add_child(pong)
	hide()


func _player_disconnected(_id):
	if multiplayer.is_server():
		_end_game("Client disconnected")
	else:
		_end_game("Server disconnected")


# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	pass # This function is not needed for this project.


# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	_set_status("Couldn't connect.", false)

	multiplayer.set_multiplayer_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)


func _server_disconnected():
	_end_game("Server disconnected.")

##### Game creation functions ######

func _end_game(with_error = ""):
	if has_node("/root/Pong"):
		# Erase immediately, otherwise network might show
		# errors (this is why we connected deferred above).
		get_node(^"/root/Pong").free()
		show()

	multiplayer.set_multiplayer_peer(null) # Remove peer.
	host_button.set_disabled(false)
	join_button.set_disabled(false)

	_set_status(with_error, false)


func _set_status(text, isok):
	# Simple way to show status.
	if isok:
		status_ok.set_text(text)
		status_fail.set_text("")
	else:
		status_ok.set_text("")
		status_fail.set_text(text)


func _on_host_pressed():
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, 1) # Maximum of 1 peer, since it's a 2-player game.
	if err != OK:
		# Is another server running?
		_set_status("Can't host, address in use.",false)
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)

	multiplayer.set_multiplayer_peer(peer)
	host_button.set_disabled(true)
	join_button.set_disabled(true)
	_set_status("Waiting for player...", true)

	# Only show hosting instructions when relevant.
	port_forward_label.visible = true
	find_public_ip_button.visible = true


func _on_join_pressed():
	var ip = address.get_text()
	if not ip.is_valid_ip_address():
		_set_status("IP address is invalid.", false)
		return

	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, DEFAULT_PORT)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)

	_set_status("Connecting...", true)


func _on_find_public_ip_pressed():
	OS.shell_open("https://icanhazip.com/")
�ѯextends Area2D

const MOTION_SPEED = 150

@export var left = false

var _motion = 0
var _you_hidden = false

@onready var _screen_size_y = get_viewport_rect().size.y

func _process(delta):
	# Is the master of the paddle.
	if is_multiplayer_authority():
		_motion = Input.get_axis(&"move_up", &"move_down")

		if not _you_hidden and _motion != 0:
			_hide_you_label()

		_motion *= MOTION_SPEED

		# Using unreliable to make sure position is updated as fast
		# as possible, even if one of the calls is dropped.
		set_pos_and_motion.rpc(position, _motion)
	else:
		if not _you_hidden:
			_hide_you_label()

	translate(Vector2(0, _motion * delta))

	# Set screen limits.
	position.y = clamp(position.y, 16, _screen_size_y - 16)


# Synchronize position and speed to the other peers.
@rpc("unreliable")
func set_pos_and_motion(pos, motion):
	position = pos
	_motion = motion


func _hide_you_label():
	_you_hidden = true
	get_node(^"You").hide()


func _on_paddle_area_enter(area):
	if is_multiplayer_authority():
		# Random for new direction generated checked each peer.
		area.bounce.rpc(left, randf())
}�extends Node2D

signal game_finished()

const SCORE_TO_WIN = 10

var score_left = 0
var score_right = 0

@onready var player2 = $Player2
@onready var score_left_node = $ScoreLeft
@onready var score_right_node = $ScoreRight
@onready var winner_left = $WinnerLeft
@onready var winner_right = $WinnerRight

func _ready():
	# By default, all nodes in server inherit from master,
	# while all nodes in clients inherit from puppet.
	# set_multiplayer_authority is tree-recursive by default.
	if multiplayer.is_server():
		# For the server, give control of player 2 to the other peer.
		player2.set_multiplayer_authority(multiplayer.get_peers()[0])
	else:
		# For the client, give control of player 2 to itself.
		player2.set_multiplayer_authority(multiplayer.get_unique_id())

	print("Unique id: ", multiplayer.get_unique_id())


@rpc("any_peer", "call_local")
func update_score(add_to_left):
	if add_to_left:
		score_left += 1
		score_left_node.set_text(str(score_left))
	else:
		score_right += 1
		score_right_node.set_text(str(score_right))

	var game_ended = false
	if score_left == SCORE_TO_WIN:
		winner_left.show()
		game_ended = true
	elif score_right == SCORE_TO_WIN:
		winner_right.show()
		game_ended = true

	if game_ended:
		$ExitGame.show()
		$Ball.stop.rpc()


func _on_exit_game_pressed():
	emit_signal("game_finished")
\�9�LwG��U GST2            ����                        *   RIFF"   WEBPVP8L   /�0��?���8�D�� jZ\��S��%�[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://i1imfdcn7ui"
path="res://.godot/imported/ball.png-9a4ca347acb7532f6ae347744a6b04f7.ctex"
metadata={
"vram_texture": false
}
 GRSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name    custom_solver_bias    radius    script 	   _bundled       Script    res://logic/ball.gd ��������
   Texture2D    res://ball.png ؀ZG�U@    
   local://1 l         local://PackedScene_nlyd6 �         CircleShape2D          �ԣ@         PackedScene          	         names "         Ball    script    Area2D 	   Sprite2D    texture    Shape3D    shape    CollisionShape2D    	   variants                                          node_count             nodes        ��������       ����                            ����                           ����                   conn_count              conns               node_paths              editable_instances              version             RSRCe�xGST2   �   �      ����               � �        H  RIFF@  WEBPVP8L4  /� %Z�I�Jv�ض�Yye۶���Yٶ홲m�Ό�ğ���#Ɛc���,�}A�>e9�9��/�*�4B�4X�ti0�T,ʜ�çGI�-G�r����H���Hk�c���4�r������Imf���ih4�\�n���)���^�q���9�|�]�q�0�ލ�'8���[p�#���`�������1��d��#@M8�ٿҍS����R��q��a,8������h��82�,2�sn�p�n:�����'��������8t��HL70#,���0��j�O]���:��A3���}S�	�=0k/�`��ޓ�o�����t�����x�	�-k.�j���B���� d�4� b�"�-?�[��1/�l�u  I��\�_k�|=�6  ��{G[������q�ڜ���I�c1��ݛ-�r��ԯ��m6�O)���vРŒi��e�.�[����@  ��Ѯ�M#Rt4(?�W�4=]�����"by��j��^- P8ڟ��K����Wo �6N�>���6PF )������Zҽ86�����Ȗ�"�6Q<�d`ؠ|:�mG$(  f�6�z2��bŌ[Ai�}��{9�&�)�s�E�(\��]��j  '�-� ��K�m)��	�!��/{�N=qm��Τ��2���.�.�$�ջ#�ˉ��}��͟��O[ Nwy�?����Ih���~Y;��M3�,!���&*/UZ��uz�  ��nzј�*U��� ��N�S(��B��W��侬�t��$[�4Sa9y�����:�mm���ɧ��c��)�׏�� @J���5�җ�3+j&~�YX�t�_.y%�z�\��]*��E����  ��]��p��݄Q��|vŵ;�}�B�OR��EW�+F+�F;M�Տ�z$ �����<�,���c�G����ʣ��E��>k��r�J�l]���  �A�Q���sk�Y� ��'o� �5�����'��I!���G#-Ҥ݇��+�����i�G�)ZGc��+�E�x�/�n�������h�������Æ ��<�Y�������!�Pn�ދ:��X�����
<vʭ1���V�z�U� bvO� ���u1�dl�6����N  ��E����b_�#|�@Q�i�_Ύ��ǖ���b�����y}z����P�0��E��>��=_^  ؽ�Vg�,��S+5����Z�=�����[�]���(�^o�B
RvN�G^�m�f4  `Җ��xx^�^ �S#0�_8=I��I�wN~�Ƽ�����x`�Ch�+���>	ma�5������/Y�>�$9�`�s�z������Gڽ̧K��z<<��2%s���I�W�ϵ���BY|5� v�}��~֣߶Y}>�&VP[ql�z{�^��t��>� !�9N���%�����e�ZuϮ?- ��a��ڗ�j7y*Xf��JK�$�+L$�"P%���@���wB��E �5!�L�)!�L	  �?݄�����\�XD@l��(������`` ��.�ϩ��z�?u��Kt�_��=��	Q��V�?X ���]�:>�B���2�ɸ��rH�;��~�H�<��+�kS%m�'-�g&�5�D���RYݭN�G��3���i��	M!ZI �(%@4:�����_��~���ض|�;�Tш$-���XT�����?0��"��w@⯎y#�tv��Y�X�� !��fP6���Q���2��k�a�u ��VGi��2���*s��vt!�XJ}&�\�����o[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://brwp8bimc75uu"
path="res://.godot/imported/icon.webp-e94f9a68b0f625a567a797079e4d325f.ctex"
metadata={
"vram_texture": false
}
 Se��+���i{�RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://logic/lobby.gd ��������      local://PackedScene_gghvo          PackedScene          	         names "   &      Lobby    layout_mode    anchors_preset    anchor_left    anchor_top    anchor_right    anchor_bottom    offset_left    offset_top    offset_right    offset_bottom    grow_horizontal    grow_vertical    size_flags_horizontal    size_flags_vertical    Control    Title    text    Label    LobbyPanel    script    Panel    AddressLabel    Address 	   LineEdit    HostButton    Button    JoinButton 	   StatusOk    StatusFail    PortForward    visible    FindPublicIP    LinkButton    _on_host_pressed    pressed    _on_join_pressed    _on_find_public_ip_pressed    	   variants    )                     ?     ��     H�     �C     HC                  RC      B     �C     �B      Multiplayer Pong       C     �C                A     xB     �A      Address      �A     XB   
   127.0.0.1      pB     �B      Host      C      Join      �B             �     C     �B     8C   i   If you want non-LAN clients to connect,
make sure the port 8910 in UDP
is forwarded checked your router.      C     C     �C     &C      Find your public IP address       node_count             nodes       ��������       ����                                                    	      
                                                ����            	      
   	      
                                          ����            	         	      
                                         ����                     	      
                                         ����                     	   	   
                                         ����                     	      
                                         ����                     	   	   
                                         ����                     	   	   
                                   ����                     	   	   
                                   ����                            	   !   
   "      #              !       ����                  $      %   	   &   
   '      (             conn_count             conns              #   "                    #   $              
      #   %                    node_paths              editable_instances              version             RSRCn�{�GST2             ����                         0   RIFF(   WEBPVP8L   /�0��?���&b���� ��A X����š�[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://bjw2yb853klh2"
path="res://.godot/imported/paddle.png-0e798fb0912613386507c9904d5cc01a.ctex"
metadata={
"vram_texture": false
}
 ������I����'RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name    custom_solver_bias    radius    height    script 	   _bundled       Script    res://logic/paddle.gd ��������
   Texture2D    res://paddle.png EJ��[؉*   
   local://1 {         local://PackedScene_pxft0 �         CapsuleShape2D          J$�@      �ټA         PackedScene          	         names "         Paddle    script    Area2D 	   Sprite2D    texture    Shape3D    shape    CollisionShape2D    You    offset_left    offset_top    offset_right    offset_bottom    size_flags_horizontal    size_flags_vertical    text    Label    _on_paddle_area_enter    area_entered    	   variants    
                                     ��     �     �A     ��                   You       node_count             nodes     0   ��������       ����                            ����                           ����                           ����   	      
                                 	             conn_count             conns                                       node_paths              editable_instances              version             RSRCRSRC                    PackedScene            ��������                                                  Player1    Player2    resource_local_to_scene    resource_name 	   _bundled    script       Script    res://logic/pong.gd ��������
   Texture2D    res://separator.png ����!-;   PackedScene    res://paddle.tscn  \&P�Q   PackedScene    res://ball.tscn ����>      local://PackedScene_td53x �         PackedScene          	         names "   %      Pong    script    Node2D 
   ColorRect    offset_right    offset_bottom    grow_horizontal    grow_vertical    color 
   Separator 	   position    texture 	   Sprite2D    Player1 	   modulate    left    Shape3D    You    Player2    Ball 
   ScoreLeft    offset_left    offset_top    size_flags_horizontal    size_flags_vertical    text    Label    ScoreRight    WinnerLeft    visible    WinnerRight 	   ExitGame    Button 	   Camera2D    offset    _on_exit_game_pressed    pressed    	   variants                        D     �C         q�>��>��(>  �?
     �C  HC                           �?  �?  �?
   ��B;�<C           �?      �?  �?
   R8D;�<C         
   �1�Cf�=C     pC      A     �C     �A             0      �C            >C     *C    ��C     8C      The Winner!      �C    ��C     �C   
   Exit Game       node_count             nodes     �   ��������       ����                            ����                                                	   ����   
                        ���               
   	      
               ���               
                  ���         
                        ����                                                               ����                                                               ����                                                                     ����                                                                      ����                                                               !   !   ����   "                conn_count             conns        
       $   #                    node_paths              editable_instances                                version             RSRC��kF@~�GST2      �     ����                �       2   RIFF*   WEBPVP8L   /�c0��?��� ��i;���E���}a �9x�C�[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://b10swafhe08oj"
path="res://.godot/imported/separator.png-f981c8489b9148e2e1dc63398273da74.ctex"
metadata={
"vram_texture": false
}
 �4}�s��wA�[remap]

path="res://.godot/exported/133200997/export-f46c71a9b7f0892a5bf2bd9cf0943875-ball.scn"
��Wm�S�8"G�[remap]

path="res://.godot/exported/133200997/export-23186f883164cbeaffe487e6aecd5af8-lobby.scn"
eB��t������[remap]

path="res://.godot/exported/133200997/export-71b5ab2463e97738099ce6f4a2aa61d7-paddle.scn"
p����c�rj[remap]

path="res://.godot/exported/133200997/export-84d343c4ab84bd4c0000a57675c7d9cd-pong.scn"
�.�7��H����Nlist=Array[Dictionary]([])
���1RIFF  WEBPVP8L  /� 㶍�������3"&�6�Eeu��Z�$I�$�9HsF�����Ͷ���r�ms$��Ck���K�Zk<�`j8��h��Z'L4�;���ք���랥X���\L��w��cۖ*�~�K;��n��2RBB�v�z��mA%��+C�7�mp���F ���m$E�2�	r��??��m۵��b۶�*��ζm'��پ���e�o���
P�i�;D�E�~�g�,�1�\���5�����?}�i�����)cz� w_rlۦ����߲�������q��m�$�� �[�b@	r�,��BX�Z�2�7PQs?>���k��PgQ3W�L}f��-M��١�N$w`^b�Q�áK�ي��#�}�p�Ē`!S������H�ՙ��`��\!i!�宆�j�EvϏQ��`j_�X,��WL,�1U���?] ��BA�}c�$�ߒI���"�s��Eg�3/��N>�:���Q���=WtN�@�j��{�=? �zk"]����R>�-�:�$"��0_���nCG$� �nEt8�9@���C(�̝��:f� �က�m�bpD�J�A����a�ƒ���B}��+x��Fm�0��+��dU�+*�gJ���T: ҦV�"�S�0��:@ ������ݍ��-�H 	�~ep��ڠQ���:�"4D&�B5Rp,ke�I�
r^��QF)$�u
�V�=�m���e��tl%}L�X�fI����Ά��J��7P"�x��ס��3/�]޼}�q��W���̑��U+���neQ��̦���Ύ��vs�0�����h�M���`��M�4w%ϖR3�!�5+Ŕ����<42>�@Ir �@O��:���DD,B���k�ۜ�/�T�M��x�ȱ\˥�^�`S�aR`yp�eǑ6���y��<��3�*�ؤ��MR]��F�Q�@ 	��[��H��JO�䝧�?r���n�]�hx<���)�SaO'��}��Ak]+��kA���F���4_����3�V�hh� &�k 0s���cP��ۓ<p��%��,h	�ۏ�g0�t��hz|���K�rU9��E*e����q���5lkF��-�\O&�o�yOT-�,JOb��u�c{�T���xy^���ϟ����d�$H�TNU;Ϫ�.N�լ�!5�����G��X��akX�A��QM׆@��Ksr��bY�|���������r���إ+1�qr]��ΘN��U��x��r�1��k^H��:m���\��<&slѡ>�_����!݋��p5T} 
r�6�~��H2����F|���W8��7w�3�?\�}y�`ӟ,���ޮO����	�5}m���hy���O��Zr]�;�4�8�n��)��c0?$�g�N����PƼ��ތac"9g�m�-�oΛ_w��_��[���Sj|��1��ZXp���D獪���p.�����;}�	Z�����6��0�s����s��YV�a�F��*2�<�����x�w�k'��@�SBP`�#�:���C.�.!������9�Z�Q-ԑ�6���&���BwK�Q���=i��0���K|��c��kxr�a0��=�[ �c�p����w��>(Թ�J�R`M�8���) �p���P`S����|S8��� �Fe�
��!e��d3���4��M�n��c��ם[%�Q��#�������=S���$��y�8z��7�L�5�F<F��ʃ����K��O!�i@��H��K`����PQ�"��"i�K+(���_|�#�ߖ�������u�   ؀ZG�U@    res://ball.png����>   res://ball.tscnT��jT3R2   res://icon.webp�d�S�k�   res://lobby.tscnEJ��[؉*   res://paddle.png \&P�Q   res://paddle.tscnztfF!   res://pong.tscn����!-;   res://separator.png���Rf�#   res://bin/Pong Multiplayer.icon.png��%�''�H/   res://bin/Pong Multiplayer.apple-touch-icon.png-��_>   res://bin/Pong Multiplayer.png�� ��ӫECFG      application/config/name         Pong Multiplayer   application/config/description�      �   A multiplayer demo of the classical pong game.
One of the players should press 'host', while the
other should select the address and press 'join'.     application/config/tags8   "         2d     demo       network 	   official       application/run/main_scene         res://lobby.tscn   application/config/features   "         4.1    application/config/icon         res://icon.webp "   display/window/size/viewport_width      �  #   display/window/size/viewport_height      �     display/window/stretch/mode         canvas_items   display/window/stretch/aspect         expand     input/move_down$              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode         physical_keycode       	   key_label             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventJoypadMotion        resource_local_to_scene           resource_name             device            axis      
   axis_value       �?   script            InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode    Z      physical_keycode       	   key_label             unicode           echo          script            InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode    S      physical_keycode       	   key_label             unicode           echo          script         input/move_up$              deadzone      ?      events              InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode         physical_keycode       	   key_label             unicode           echo          script            InputEventJoypadButton        resource_local_to_scene           resource_name             device            button_index         pressure          pressed           script            InputEventJoypadMotion        resource_local_to_scene           resource_name             device            axis      
   axis_value       ��   script            InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode    A      physical_keycode       	   key_label             unicode           echo          script            InputEventKey         resource_local_to_scene           resource_name             device         	   window_id             alt_pressed           shift_pressed             ctrl_pressed          meta_pressed          pressed           keycode    W      physical_keycode       	   key_label             unicode           echo          script      �O<���&S=�Օx