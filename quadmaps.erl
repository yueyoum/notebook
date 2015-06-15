%%%-------------------------------------------------------------------
%%% @author wang <yueyoum@gmail.com>
%%% @copyright (C) 2015
%%% @doc
%%%
%%% @end
%%% Created : 2015-06-14 00:11
%%%-------------------------------------------------------------------
-module(quadmaps).
-author("wang").

%% API
-export([new/5,
         put/4,
         delete/2,
         find/5,
         test_/7]).

-record(quad, {
    id          :: integer(),
    bounds      :: {float(), float(), float(), float()},            % {MinX, MinY, MaxX, MaxY}
    quardrants  :: {integer(), integer(), integer(), integer()},    % {q1, q2, q3, q4}
    parent      :: integer() | undefined,
    elements    :: []
}).


new(MinX, MinY, MaxX, MaxY, SplitTimes) when SplitTimes >= 0 ->
    Quad = create_quadrand(1, {MinX, MinY, MaxX, MaxY}, undefined),
    QuadMaps = maps:put(Quad#quad.id, Quad, maps:new()),
    QM = do_create_quad(SplitTimes, Quad, QuadMaps),
    {QM, maps:new()}.

put({QuadMaps, ElementMaps}, Id, X, Y) ->
    case maps:is_key(Id, ElementMaps) of
        true -> update({QuadMaps, ElementMaps}, Id, X, Y);
        false -> insert({QuadMaps, ElementMaps}, Id, X, Y)
    end.

delete({QuadMaps, ElementMaps}, Id) ->
    case maps:find(Id, ElementMaps) of
        {ok, Qid} ->
            NewElementMaps = maps:remove(Id, ElementMaps),
            Quad = maps:get(Qid, QuadMaps),
            NewQuadMaps = maps:put(Qid, Quad#quad{elements = lists:delete(Id, Quad#quad.elements)}, QuadMaps),
            {NewQuadMaps, NewElementMaps};
        error ->
            {QuadMaps, ElementMaps}
    end.


find({QuadMaps, _}, X1, Y1, X2, Y2) ->
    do_get(maps:get(1, QuadMaps), QuadMaps, X1, Y1, X2, Y2, []).

do_get(#quad{quardrants = {}, elements = Es}=Quad, _, X1, Y1, X2, Y2, Got) ->
    case quadrand_contains(Quad, X1, Y1, X2, Y2) of
        true -> Got ++ Es;
        false -> Got
    end;

do_get(#quad{quardrants = {Q1ID, Q2ID, Q3ID, Q4ID}}=Quad, QuadMaps, X1, Y1, X2, Y2, Got) ->
    case quadrand_contains(Quad, X1, Y1, X2, Y2) of
        true ->
            E1 = do_get(maps:get(Q1ID, QuadMaps), QuadMaps, X1, Y1, X2, Y2, Got),
            E2 = do_get(maps:get(Q2ID, QuadMaps), QuadMaps, X1, Y1, X2, Y2, E1),
            E3 = do_get(maps:get(Q3ID, QuadMaps), QuadMaps, X1, Y1, X2, Y2, E2),
            E4 = do_get(maps:get(Q4ID, QuadMaps), QuadMaps, X1, Y1, X2, Y2, E3),
            E4;
        false ->
            Got
    end.



insert({QuadMaps, ElementMaps}, Id, X, Y) ->
    QuadLocated = find_quadrand_by_point(QuadMaps, X, Y),
    NewElementMaps = maps:put(Id, QuadLocated#quad.id, ElementMaps),

    NewQuadMaps = maps:put(
        QuadLocated#quad.id,
        QuadLocated#quad{elements = [Id | QuadLocated#quad.elements]},
        QuadMaps
    ),

    {NewQuadMaps, NewElementMaps}.

update({QuadMaps, ElementMaps}, Id, X, Y) ->
    Qid = maps:get(Id, ElementMaps),
    Quad = maps:get(Qid, QuadMaps),
    QuadLocated = do_update(Quad, QuadMaps, X, Y),
    case Quad#quad.id == QuadLocated#quad.id of
        true ->
            {QuadMaps, ElementMaps};
        false ->
            NewQuadMaps1 = maps:put(Quad#quad.id, Quad#quad{elements = lists:delete(Id, Quad#quad.elements)}, QuadMaps),
            NewQuadMaps2 = maps:put(QuadLocated#quad.id, QuadLocated#quad{elements = [Id | QuadLocated#quad.elements]}, NewQuadMaps1),
            NewElementMaps = maps:put(Id, QuadLocated#quad.id, ElementMaps),
            {NewQuadMaps2, NewElementMaps}
    end.

do_update(Quad, QuadMaps, X, Y) ->
    case quadrand_contains(Quad, X, Y) of
        true ->
            find_quadrand_by_point(Quad, QuadMaps, X, Y);
        false ->
            do_update(maps:get(Quad#quad.parent, QuadMaps), QuadMaps, X, Y)
    end.


do_create_quad(0, _, QuadMaps) ->
    QuadMaps;

do_create_quad(SplitTimes, #quad{id = Id, bounds = Bounds} = Quad, QuadMpas) when SplitTimes > 0 ->
    QuadSize = maps:size(QuadMpas),
    {Bounds1, Bounds2, Bounds3, Bounds4} = split_bounds(Bounds),

    Quadrand1 = create_quadrand(QuadSize + 1, Bounds1, Id),
    Quadrand2 = create_quadrand(QuadSize + 2, Bounds2, Id),
    Quadrand3 = create_quadrand(QuadSize + 3, Bounds3, Id),
    Quadrand4 = create_quadrand(QuadSize + 4, Bounds4, Id),

    NewQuad = Quad#quad{
        quardrants = {
            Quadrand1#quad.id,
            Quadrand2#quad.id,
            Quadrand3#quad.id,
            Quadrand4#quad.id
        }
    },

    NewQuadMaps1 = maps:put(NewQuad#quad.id, NewQuad, QuadMpas),

    NewQuadMaps2 = lists:foldl(
        fun(Q, Acc) -> maps:put(Q#quad.id, Q, Acc) end,
        NewQuadMaps1,
        [Quadrand1, Quadrand2, Quadrand3, Quadrand4]
    ),

    NewQuadMaps3 = do_create_quad(SplitTimes-1, Quadrand1, NewQuadMaps2),
    NewQuadMaps4 = do_create_quad(SplitTimes-1, Quadrand2, NewQuadMaps3),
    NewQuadMaps5 = do_create_quad(SplitTimes-1, Quadrand3, NewQuadMaps4),
    NewQuadMaps6 = do_create_quad(SplitTimes-1, Quadrand4, NewQuadMaps5),

    NewQuadMaps6.


split_bounds({MinX, MinY, MaxX, MaxY}) ->
    CenterX = (MinX + MaxX) / 2,
    CenterY = (MinY + MaxY) / 2,

    {
        {CenterX, CenterY, MaxX, MaxY},
        {MinX, CenterY, CenterX, MaxY},
        {MinX, MinY, CenterX, CenterY},
        {CenterX, MinY, MaxX, CenterY}
    }.


create_quadrand(Id, Bounds, Parent) ->
    #quad{
        id = Id,
        bounds = Bounds,
        quardrants = {},
        parent = Parent,
        elements = []
    }.


find_quadrand_by_point(QuadMaps, X, Y) ->
    find_quadrand_by_point(maps:get(1, QuadMaps), QuadMaps, X, Y).

find_quadrand_by_point(Quad, QuadMaps, X, Y) ->
    do_find_quadrad_by_point(Quad, QuadMaps, X, Y).


do_find_quadrad_by_point(#quad{quardrants = {}} = Quad, _, _, _) ->
    Quad;

do_find_quadrad_by_point(#quad{quardrants = {Q1ID, Q2ID, Q3ID, Q4ID}}, QuadMaps, X, Y) ->
    Q1 = maps:get(Q1ID, QuadMaps),

    QuadLocated =
    case quadrand_contains(Q1, X, Y) of
        true ->
            Q1;
        false ->
            Q2 = maps:get(Q2ID, QuadMaps),
            case quadrand_contains(Q2, X, Y) of
                true ->
                    Q2;
                false ->
                    Q3 = maps:get(Q3ID, QuadMaps),
                    case quadrand_contains(Q3, X, Y) of
                        true ->
                            Q3;
                        false ->
                            Q4 = maps:get(Q4ID, QuadMaps),
                            case quadrand_contains(Q4, X, Y) of
                                true ->
                                    Q4;
                                false ->
                                    erlang:error("Point Out of QuadMaps")
                            end
                    end
            end
    end,

    do_find_quadrad_by_point(QuadLocated, QuadMaps, X, Y).

quadrand_contains(#quad{bounds = {MinX, MinY, MaxX, MaxY}}, X, Y) ->
    X > MinX andalso X =< MaxX andalso Y > MinY andalso Y =< MaxY.

quadrand_contains(#quad{bounds = {MinX, MinY, MaxX, MaxY}}, X1, Y1, X2, Y2) ->
    X1 =< MaxX andalso X2 > MinX andalso Y1 =< MaxY andalso Y2 > MinY.





test_(MinX, MinY, MaxX, MaxY, SplitTimes, ElementAmount, TestTimes) ->
    <<A:32, B:32, C:32>> = crypto:rand_bytes(12),
    random:seed(A, B, C),

    Q = quadmaps:new(MinX, MinY, MaxX, MaxY, SplitTimes),
    Q1 =
    lists:foldl(
        fun(Id, Acc) ->
            X = random:uniform(MaxX - MinX) + MinX,
            Y = random:uniform(MaxY - MinY) + MinY,
            quadmaps:put(Acc, Id, X, Y)
        end,
        Q,
        lists:seq(1, ElementAmount)
    ),

    Fun = fun(_) ->
        X1 = random:uniform(MaxX - MinX) + MinX,
        X2 = X1 + 60,
        Y1 = random:uniform(MaxY - MinY) + MinY,
        Y2 = Y1 + 60,

        R = quadmaps:find(Q1, X1, Y1, X2, Y2),
        io:format("Find Element Amount: ~p~n", [length(R)])
    end,

    timer:tc(lists, foreach, [Fun, lists:seq(1, TestTimes)]).
