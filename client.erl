-module(client).
%% Exported Functions
-export([start/2]).

%%-define(TCP_OPTIONS_CLIENT, [binary, {packet, 0}, {active, false}]).

%% API Functions
start(ServerPid, MyName) ->
    ClientPid = spawn(fun() -> init_client(ServerPid, MyName) end),
    process_commands(ServerPid, MyName, ClientPid).

init_client(ServerPid, MyName) ->
    ServerPid ! {client_join_req, MyName, self()},  %% TODO: COMPLETE
    process_requests().

%% Local Functions
%% This is the background task logic
process_requests() ->
    receive
        {join, Name} ->
            io:format("[JOIN] ~s joined the chat~n", [Name]),
            process_requests();
            %% TODO: ADD SOME CODE
        {leave, Name} ->
            io:format("[LEAVE] ~s leaved the chat~n", [Name]),
            %% TODO: ADD SOME CODE
            process_requests();
        {message, Name, Text} ->
            io:format("[~s] ~s", [Name, Text]),
            process_requests();
            %% TODO: ADD SOME CODE
        exit ->
            ok
    end.

%% This is the main task logic
process_commands(ServerPid, MyName, ClientPid) ->
    %% Read from standard input and send to server
    Text = io:get_line("-> "),
    if
        Text  == "exit\n" ->
            ServerPid ! {client_leave_req, MyName, ClientPid},  %% TODO: COMPLETE
            ok;
        Text == "message\n" ->
            Nombre = string:trim(io:get_line("[ENTER FILENAME]->")),
            ServerPid ! {client_send_file, MyName, ClientPid, Nombre},  %% TODO: COMPLETE
            Otro = string:trim(io:get_line("[ENTER FILEPATH]->")),
            send_file("localhost", Otro, 5678),
            process_commands(ServerPid, MyName, ClientPid);
        Text == "lista\n" ->
            ServerPid ! {files_to_Download, MyName, ClientPid},
            process_commands(ServerPid, MyName, ClientPid);

        Text == "Descarga\n" ->

            Nombre = string:trim(io:get_line("[ENTER FILENAME]->")),
            Ip=local_ip_v4(),
            ServerPid ! {client_download_file, MyName, ClientPid, Nombre, Ip},
            {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            {ok, Sock} = gen_tcp:accept(LSock),       
            file_receiver_loop(Sock,Nombre,[]),
            ok = gen_tcp:close(Sock),
            ok = gen_tcp:close(LSock),
            process_commands(ServerPid, MyName, ClientPid);

        true ->
            ServerPid ! {send, MyName, Text},  %% TODO: COMPLETE
            process_commands(ServerPid, MyName, ClientPid)
    end.

%Funcion para generar el socket de conexion entre servidor y client_leave_req
  send_file(Host,FilePath,Port)->
    {ok, Socket} = gen_tcp:connect(Host, Port,[binary, {packet, 0}]),
    %FilenamePadding = string:left(Filename, 30, $ ), %%Padding with white space
    %gen_tcp:send(Socket,Filename),
    Ret=file:sendfile(FilePath, Socket),
    ok = gen_tcp:close(Socket).

file_receiver_loop(Socket,Filename,Bs)->
    io:format("~nTransmision en curso~n"),
    case gen_tcp:recv(Socket, 0) of
    {ok, B} ->
        file_receiver_loop(Socket, Filename,[Bs, B]);
    {error, closed} ->
        save_file(Filename,Bs)
end.
save_file(Filename,Bs) ->
    io:format("~nFilename: ~p",[Filename]),
    {ok, Fd} = file:open("./descargas/"++Filename, write),
    file:write(Fd, Bs),
    file:close(Fd),
    io:format("~nTransmision finalizado~n").

local_ip_v4() ->
    {ok, Addrs} = inet:getifaddrs(),
    hd([
         Addr || {_, Opts} <- Addrs, {addr, Addr} <- Opts,
         size(Addr) == 4, Addr =/= {127,0,0,1}
    ]).