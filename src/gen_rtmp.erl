  %%%---------------------------------------------------------------------------------------
%%% @author     Roberto Saccon <rsaccon@gmail.com> [http://rsaccon.com]
%%% @author     Stuart Jackson <simpleenigmainc@gmail.com> [http://erlsoft.org]
%%% @author     Luke Hubbard <luke@codegent.com> [http://www.codegent.com]
%%% @copyright  2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%% @doc        Generalized RTMP application behavior module
%%% @reference  See <a href="http://erlyvideo.googlecode.com" target="_top">http://erlyvideo.googlecode.com</a> for more information
%%% @end
%%%
%%%
%%% The MIT License
%%%
%%% Copyright (c) 2007 Luke Hubbard, Stuart Jackson, Roberto Saccon
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%%
%%%---------------------------------------------------------------------------------------
-module(gen_rtmp).
-author('rsaccon@gmail.com').
-author('simpleenigmainc@gmail.com').
-author('luke@codegent.com').
-include("../include/ems.hrl").

-export([connect/2,createStream/2,play/2,deleteStream/2,closeStream/2,pause/2, pauseRaw/2, stop/2,publish/2]).

-export([behaviour_info/1]).


%%-------------------------------------------------------------------------
%% @spec (Callbacks::atom()) -> CallBackList::list()
%% @doc  List of require funcations in a RTMP application
%% @hidden
%% @end
%%-------------------------------------------------------------------------
behaviour_info(callbacks) -> [{createStream,3},{play,3},{stop,3},{pause,3},{deleteStream,3},{closeStream,3},{publish,3},{live,3},{append,3}];
behaviour_info(_Other) -> undefined.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a connect command and responds
%% @end
%%-------------------------------------------------------------------------
connect(AMF, State) ->
    ?D("invoke - connect"),   
    NewAMF = AMF#amf{
        command = '_result', 
        id = 1, %% muriel: dirty too, but the only way I can make this work
        type = invoke,
        args= [
            [{capabilities, 31}, {fmsVer, "RubyIZUMI/0,1,2,0"}],
            [{code, ?NC_CONNECT_SUCCESS},
            {level, "status"}, 
            {description, "Connection succeeded."}]]},
    gen_fsm:send_event(self(), {invoke, NewAMF}),
    State.



%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a createStream command and responds
%% @end
%%-------------------------------------------------------------------------
createStream(AMF, State) -> 
    ?D({"invoke - createStream", AMF}),
    Id = 1, % New stream ID
    NewAMF = AMF#amf{
      id = 2.0,
    	command = '_result',
    	args = [null, Id]},
    % gen_fsm:send_event(self(), {send, {#channel{timestamp = 0, id = 2},NewAMF}}),
    gen_fsm:send_event(self(), {invoke, NewAMF}),
    gen_fsm:send_event(self(), {send, {#channel{timestamp = 0, id = 2, stream = 0, type = ?RTMP_TYPE_CHUNK_SIZE}, ?RTMP_PREF_CHUNK_SIZE}}),
    State.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a deleteStream command and responds
%% @end
%%-------------------------------------------------------------------------
deleteStream(_AMF, State) ->  
    ?D("invoke - deleteStream"),
    State.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a play command and responds
%% @end
%%-------------------------------------------------------------------------
play(AMF, State) -> 
    Channel = #channel{id = 5, timestamp = 0, stream = 1},
    [_Null,{string,Name}] = AMF#amf.args,
    ?D({"invoke - play", Name, AMF}),
    gen_fsm:send_event(self(), {send, {Channel#channel{id = 2,type = ?RTMP_TYPE_CONTROL, stream = 0}, <<0,4,0,0,0,1>>}}),
    gen_fsm:send_event(self(), {send, {Channel#channel{id = 2,type = ?RTMP_TYPE_CONTROL, stream = 0}, <<0,0,0,0,0,1>>}}),
    % NewAMF = AMF#amf{
    %     command = 'onStatus', 
    %     args= [null,[{level, "status"}, 
    %                 {code, "NetStream.Play.Reset"}, 
    %                 {description, "Resetting NetStream."}]]}, %, {details, Name}, {clientid, NextChannel#channel.stream}
    % gen_fsm:send_event(From, {send, {NextChannel,NewAMF}}),
    NewAMF2 = AMF#amf{
        command = 'onStatus',
        type = invoke,
        id = 0,
        args= [null,[{code, ?NS_PLAY_START}, 
                    {level, "status"}, 
                    {description, "-"}]]}, %, {details, Name}, {clientid, NextChannel#channel.stream}
    gen_fsm:send_event(self(), {invoke, NewAMF2}),
    gen_fsm:send_event(self(), {play, Name, Channel#channel.stream}),
    State.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a pause command and responds
%% @end
%%-------------------------------------------------------------------------
pause(AMF, State) -> 
    ?D({"invoke - pause", AMF}),
    % gen_fsm:send_event(From, {pause}),
    State.


pauseRaw(AMF, State) -> pause(AMF, State).


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a publish command and responds
%% @end
%%-------------------------------------------------------------------------
publish(AMF, State) -> 
    ?D("invoke - publish"),
    Args = AMF#amf.args,
    case Args of
        [{null,null},{string,Name},{string,Action}] ->
            case list_to_atom(Action) of
                record -> 
                    ?D({"Publish - Action - record",Name}),
                    gen_fsm:send_event(self(), {publish, record, Name});
                append -> 
                     ?D({"Publish - Action - append",Name}),
                     gen_fsm:send_event(self(), {publish, append, Name});
                live -> 
                    ?D({"Publish - Action - live",Name}),
                    gen_fsm:send_event(self(), {publish, live, Name});
                _OtherAction -> 
                    ?D({"Publish Ignoring - ", _OtherAction})
            end;
		[{null,null},{string,Name}] -> % second arg is optional
			?D({"Publish - Action - live",Name}),
            gen_fsm:send_event(self(), {publish, live, Name});
        _ -> ok
    end,
    State.


%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a stop command and responds
%% @end
%%-------------------------------------------------------------------------
stop(_AMF, State) -> 
    ?D("invoke - stop"),
    gen_fsm:send_event(self(), {stop}),
    State.

%%-------------------------------------------------------------------------
%% @spec (From::pid(),AMF::tuple(),Channel::tuple) -> any()
%% @doc  Processes a closeStream command and responds
%% @end
%%-------------------------------------------------------------------------
closeStream(_AMF, State) ->
    ?D("invoke - closeStream"),
    gen_fsm:send_event(self(), {stop}),
    State.

