-module(chat_cowboy_ws_handler).

-export([init/2]).
-export([websocket_init/1]).
-export([websocket_handle/2]).
-export([websocket_info/2]).
-export([websocket_terminate/2]).

-define(CHATROOM_NAME, ?MODULE).
-define(TIMEOUT, 5 * 60 * 1000). % Innactivity Timeout

-record(state, {name, handler}).

%% API

init(Req, _State) ->
  {cowboy_websocket, Req, get_name(Req)}.

websocket_init(State) ->
  % Create the handler from our custom callback
  Handler = ebus_proc:spawn_handler(fun chat_erlbus_handler:handle_msg/2, [self()]),
  ebus:sub(Handler, ?CHATROOM_NAME),
  {[], #state{name = State, handler = Handler}}.

websocket_handle({text, Msg}, State) ->
  ebus:pub(?CHATROOM_NAME, {State#state.name, Msg}),
  {[], State};
websocket_handle(_data, State) ->
  {[], State}.

websocket_info({message_published, {Sender, Msg}}, State) ->
  {reply, {text, jiffy:encode({[{sender, Sender}, {msg, Msg}]})}, State};
websocket_info(_Info, State) ->
  {[], State}.

websocket_terminate(_Reason, State) ->
  % Unsubscribe the handler
  ebus:unsub(State#state.handler, ?CHATROOM_NAME),
  ok.

%% Private methods

get_name(Req) ->
  {Host, Port} = cowboy_req:peer(Req),
  Name = list_to_binary(string:join([inet_parse:ntoa(Host), 
    ":", io_lib:format("~p", [Port])], "")),
  Name.
  