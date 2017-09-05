{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

{-| This module implements the core algebra of Karps with respect to
structured transforms. It takes functional structured transforms and flattens
them into simpler, flat projections.

This is probably one of the most complex parts of the optimizer.
-}
module Spark.Core.Internal.StructuredFlattening(
  structuredFlatten
) where

import Formatting
import Spark.Core.Internal.Utilities
import Data.List(nub)
import Data.Maybe(catMaybes)
import qualified Data.Vector as V
import qualified Data.List.NonEmpty as N
import Control.Monad.Identity
import Data.List.NonEmpty(NonEmpty(..))

import Spark.Core.Internal.StructuredBuilder
import Spark.Core.Internal.StructureFunctions
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.NodeBuilder(nbName)
import Spark.Core.Internal.ContextStructures(ComputeGraph)
import Spark.Core.Internal.TypesStructures(DataType(..), StrictDataType(Struct), StructType(..), StructField(..))
import Spark.Core.Internal.TypesFunctions(extractFields, structType, structField)
import Spark.Core.Internal.DAGFunctions(graphMapVertices, graphMapVertices', completeVertices)
import Spark.Core.Internal.DAGStructures(VertexId, Graph(..), vertexData)
import Spark.Core.Internal.DatasetStructures(OperatorNode, StructureEdge(ParentEdge))
import Spark.Core.StructuresInternal(FieldName(..), FieldPath(..), fieldPath', fieldName)
import Spark.Core.Try

{-| Takes a graph that may contain some functional nodes, and attempts to
apply these nodes as operands, flattening the inner functions and the groups
in the process.

This outputs a graph where all the functional elements have been replaced by
their low-level, imperative equivalents.

It works by doing the following:
 - build a new DAG in which the edges track the groupings.
 - traverse the DAG and apply the functional nodes
 - reconstuct the final DAG
-}
structuredFlatten :: ComputeGraph -> Try ComputeGraph
structuredFlatten cg = do
  fg <- _fgraph cg
  fg' <- _performTrans fg
  _fgraphBack cg fg'

data StackMove = Enter | Exit deriving (Eq, Show)

type TypedColOp = (ColOp, DataType)

{-| The different types of nodes.
-}
data FNodeType =
    FIdentity
  -- | FFilter
  | FDistributedTransform ColOp -- Parents are assumed to be distributed too.
  | FLocalTransform ColOp -- Parents are assumed to be local or aggs.
  | FImperativeAggregate AggOp -- A call to a low-level aggregate (reduce)
  | FShuffle StackMove
  -- | FTransform StackMove
  | FReduce StackMove
  | FUnknown
  deriving (Eq, Show)

data FNode = FNode FNodeType CoreNodeInfo deriving (Eq, Show)

type FGraph = Graph FNode StructureEdge

type GroupStack = [TypedColOp]

data NodeParseType =
    FunctionalReduce
  | FunctionalShuffle deriving (Eq, Show)

data FunctionalNodeAnalysis = FunctionalNodeAnalysis {
  fnaId :: !VertexId,
  fnaType :: !NodeParseType,
  fnaParent :: !VertexId, -- The direct parent of the functional node
  fnaFunctionStart :: !VertexId, -- The placeholder that starts
  fnaFunctionEnd :: !VertexId -- The final node of the function that ends
} deriving (Eq, Show)

{-| Converts the compute graph to the flattening graph.

This works by making multiple traversals on the graph:
 - gather (and check) the flattening operators
 - replace modify the nodes and edges of these operators with f-edges
-}
_fgraph :: ComputeGraph -> Try FGraph
_fgraph cg = undefined

_gatherCheckFunctionalOps :: Graph (CoreNodeInfo, VertexId) StructureEdge -> Try [FunctionalNodeAnalysis]
_gatherCheckFunctionalOps g = catMaybes <$> l' where
  l = V.toList . (vertexData<$>) . gVertices <$> g'
  f (_, _, x) = x
  l' = (f <$>) <$> l
  g' = graphMapVertices g _checkFunctional

_checkFunctional ::
  (CoreNodeInfo, VertexId) ->
  [((CoreNodeInfo, VertexId, Maybe FunctionalNodeAnalysis), StructureEdge)] ->
  Try (CoreNodeInfo, VertexId, Maybe FunctionalNodeAnalysis)
_checkFunctional (cni, vid) l =
  case cniOp cni of
    -- Look at the standard operator to see if we know about it:
    NodeLocalOp so ->
      case soName so of
        x | x == nbName functionalShuffleBuilder ->
          (cni, vid, ) . Just <$> _checkFunctionalStructure l vid FunctionalShuffle
        x | x == nbName functionalReduceBuilder ->
          (cni, vid, ) . Just <$> _checkFunctionalStructure l vid FunctionalReduce
        _ -> pure (cni, vid, Nothing)
    _ -> pure (cni, vid, Nothing)

_checkFunctionalStructure :: [((CoreNodeInfo, VertexId, Maybe FunctionalNodeAnalysis), StructureEdge)] -> VertexId -> NodeParseType -> Try FunctionalNodeAnalysis
-- TODO: it does not check the rest of the edges for now, it should be checked that the rest is just logical dependencies.
_checkFunctionalStructure (((cni1, vid1, _), ParentEdge) : ((cni2, vid2, _), ParentEdge) : ((cni3, vid3, _), ParentEdge):_) vid npt =
  -- The second argument should be a placeholder
  -- The shape of the first and second argument should match
  undefined
_checkFunctionalStructure l vid _ = tryError $ sformat ("_checkFunctionalStructure: expected 3 arguments"%sh) (vid, l)

{-| Converts back to a compute graph, and makes sure that the original
inputs and outputs are the same.
-}
_fgraphBack :: ComputeGraph -> FGraph -> Try ComputeGraph
_fgraphBack = undefined

{-| Flattens the nodes given the f-graph. -}
_performTrans :: FGraph -> Try FGraph
_performTrans fg = graphMapVertices' snd <$> z where
  z = graphMapVertices fg _innerTrans

-- This is the meat of the transform here.
-- It does not do type checking, this is assumed to have been done during the
-- construction of the graph itself.
_innerTrans :: FNode -> [((GroupStack, FNode), StructureEdge)] -> Try (GroupStack, FNode)
_innerTrans (FNode nt cni) l = do
  (gs, cnis) <- _getInterestingParent l
  (gs', cni') <- _innerTrans' nt cni gs cnis
  -- TODO: there is no need to return a FNode??
  -- TODO: it could be directly converted here to the final operator?
  return (gs', FNode nt cni')

-- -- Unknown node: only accepted at the top level
-- _innerTrans (fn @ (FNode FUnknown on)) l =
--   if _inTopLevel l then pure ([], fn) else tryError $ sformat ("_innerTrans: cannot process node inside group: "%sh) on
-- -- Identity: accepted at any level if a single parent, or only at the top (for now)
-- _innerTrans (fn @ (FNode FIdentity _)) [((gs, _), ParentEdge)] = pure (gs, fn)
-- _innerTrans (fn @ (FNode FIdentity on)) l =
--   if _inTopLevel l then pure ([], fn)
--     else tryError $ sformat ("_innerTrans: identity node has too many parents for now:"%sh) on
-- _innerTrans (fn @ (FNode FShuffleEnter key value)) l =

-- For now, only accepts a single group stack at the top.
-- This should not be too much of a limitation as a start, as users can always
-- convert to a join manually.
-- Same thing for multiple arguments: only linear functions are accepted for now,
-- but nothing prevents adding joins automatically.
-- TODO: it does not check the number of parents, but this should be done
-- elsewhere already.
-- TODO: this algorithm will work best after the structure merging pass.
-- It works as follows: if there is a stack, then the dataframe has type
-- {key:{key0..keyN}, group:value}
-- Otherwise, it is just whatever the value is.
_innerTrans' :: FNodeType -> CoreNodeInfo -> GroupStack -> [CoreNodeInfo] -> Try (GroupStack, CoreNodeInfo)

_innerTrans' FUnknown cni [] _ = pure ([], cni)
_innerTrans' FUnknown cni gs _ = tryError $ sformat ("_innerTrans: cannot process node inside group: "%sh%" op:"%sh) gs cni

-- Identity gets converted to a structured transform if there is a stack.
_innerTrans' FIdentity cni [] _ = pure ([], cni)
-- We discard the shape.
_innerTrans' FIdentity (CoreNodeInfo sh' _) gs _ = pure (gs, cni) where
    co = ColExtraction (FieldPath V.empty) -- This is equivalent to the identity.
    (co', dt') = _extractTransform gs co (nsType sh')
    cni = coreNodeInfo dt' Distributed (NodeStructuredTransform co')

-- Reduce operations: the aggregation is done as a shuffle over all the keys.
_innerTrans' (FImperativeAggregate _) cni [] _ = pure ([], cni)
_innerTrans' (FImperativeAggregate ao) cni (h:t) _ = pure ([], cni') where
    (_, keyDt) = _groupType (h :| t)
    groupDt = nsType . cniShape $ cni
    dt = _keyGroupDt keyDt groupDt
    cni' = coreNodeInfo dt Distributed (NodeGroupedReduction (_wrapAgg ao))

-- Mapping operations: it simply wraps the op to account for the group, no other change.
-- TODO: only single parents are currently allowed for simplification.
-- Anything more than that requires performing join, and this is harder to
-- implement as it requires adding multiple nodes. Nothing hard though.
_innerTrans' (FDistributedTransform _) cni [] _ = pure ([], cni)
-- One parent:
_innerTrans' (FDistributedTransform co) cni (h:t) [_] =
  pure $ _doTransform (nsType . cniShape $ cni) co (h :| t)
-- Not enough parents:
_innerTrans' (FDistributedTransform _) cni _ [] =
  tryError $ sformat ("_innerTrans: not enough parent for distributed transform:"%sh) (cni)
-- Too many parents:
_innerTrans' (FDistributedTransform _) cni (gh:gt) (h1:h2:t) =
  tryError $ sformat ("_innerTrans: more than one parent is not currently supported for distributed transform:"%sh) (cni, (gh:gt), (h1:h2:t))

-- Local transform is very similar to distribute transform, except that
-- it stays local with no group.
_innerTrans' (FLocalTransform _) cni [] _ = pure ([], cni)
-- The result is distributed too here, nothing special to do.
_innerTrans' (FLocalTransform co) cni (h:t) [_] =
  pure $ _doTransform (nsType . cniShape $ cni) co (h :| t)
-- Not enough parents:
_innerTrans' (FLocalTransform _) cni _ [] =
  tryError $ sformat ("_innerTrans: not enough parent for local transform:"%sh) (cni)
-- Too many parents:
_innerTrans' (FLocalTransform _) cni (gh:gt) (h1:h2:t) =
  tryError $ sformat ("_innerTrans: more than one parent is not currently supported for local transform:"%sh) (cni, (gh:gt), (h1:h2:t))

-- Entering a shuffle: adding to the carry and make a projection
-- for the value node.
_innerTrans' (FShuffle Enter) cni gs _ = do
  (keyDt, valueDt) <- _extractGroupType (nsType . cniShape $ cni)
  let keyOp = ColExtraction (fieldPath' [_key])
  let valueOp = NodeStructuredTransform $ ColExtraction (fieldPath' [_value])
  return ((keyOp, keyDt) : gs, coreNodeInfo valueDt Distributed valueOp)
-- Exiting the shuffle: the shuffling has already been performed, to it is
-- just a matter of popping the stack.
_innerTrans' (FShuffle Exit) cni gs _ = do
  -- Try to merge the top keys and get the op/datatype for the group
  (gs', co', dt') <- _mergeWithKey gs (nsType . cniShape $ cni)
  let (co'', dt'') = _extractTransform gs' co' dt'
  let cni' = coreNodeInfo dt'' Distributed (NodeStructuredTransform co'')
  return (gs, cni')

-- Entering a reduce: nothing special to do
_innerTrans' (FReduce Enter) cni gs _ = pure (gs, cni)
-- Exiting a reduce: nothing special to do
_innerTrans' (FReduce Exit) cni gs _ = pure (gs, cni)

{-| Takes a data type, assumed to be {key:{key1:..}, group:..}, and hoists
both key1 and the content of group into the top-level.
-}
_mergeWithKey :: GroupStack -> DataType -> Try (GroupStack, ColOp, DataType)
-- Empty stack, should not happen.
_mergeWithKey [] dt = tryError $ sformat ("_mergeWithKey: empty stack "%sh) dt
-- No other keys, hoist everything to the top.
_mergeWithKey ((_, key1Dt):t) dt = do
  (_, groupDt) <- _extractGroupType dt
  let dtG = _keyGroupDt key1Dt groupDt
  return (gs, coG, dtG) where
    f ((_, dt'), idx) = (_keyExtractor idx, dt')
    gs = case t of
      [] -> [] -- No other key to process, result will be hoisted.
      _ -> f <$> (t `zip` [2..])
    coG = ColStruct (V.fromList [f1, f2]) where
          f1 = TransformField "key" (_keyExtractor 1)
          f2 = TransformField "group" _groupExtractor

-- Does the transform in a distribute manner
_doTransform :: DataType -> ColOp -> N.NonEmpty TypedColOp -> (GroupStack, CoreNodeInfo)
_doTransform dt co (h :| t) = (gs', cni') where
  (_, keyDt) = _groupType (h :| t)
  groupDt = dt
  dt' = _keyGroupDt keyDt groupDt
  cni' = coreNodeInfo dt' Distributed (NodeStructuredTransform (_wrapGroup co))
  gs' = h : t


_keyGroupDt :: DataType -> DataType -> DataType
_keyGroupDt keyDt groupDt = structType [df1, df2] where
  df1 = structField "key" keyDt
  df2 = structField "group" groupDt

_extractGroupType :: DataType -> Try (DataType, DataType)
_extractGroupType dt = do
  l <- extractFields [_key, _value] dt
  case l of
    [keyDt, valueDt] -> pure (keyDt, valueDt)
    _ -> tryError $ sformat ("_extractGroupType: expected a structure with 2 field, but got "%sh) dt

{-| Given a dataframe that already has some a group stack, wraps an existing
structured transform over this dataframe into a new structure transform that
carries over the group stack information.
-}
_extractTransform :: GroupStack -> ColOp -> DataType -> (ColOp, DataType)
_extractTransform [] co dt = (co, dt)
_extractTransform (h:t) co dt =
  -- This is simply making sure the key is passed around, since it is already
  -- in its structure.
  (ColStruct (V.fromList [keyF, groupF]), structType [key, groupDt]) where
  groupF = TransformField _value (_wrapGroup co)
  groupDt = structField "group" dt
  (_, keyDt) = _groupType (h :| t)
  key = structField "key" keyDt
  -- Directly refer to the key in the previous column.
  keyF = TransformField _key (ColExtraction (fieldPath' [_key]))


{-| Takes a col and makes sure that the extraction patterns are wrapped inside
the group instead of directly accessing the field path.
-}
_wrapGroup :: ColOp -> ColOp
_wrapGroup (ColExtraction fp) = ColExtraction (_wrapFieldPath fp)
_wrapGroup (ColFunction sn v) = ColFunction sn (_wrapGroup <$> v)
_wrapGroup (x @ ColLit{}) = x
_wrapGroup (ColStruct v) = ColStruct (f <$> v) where
  f (TransformField fn v') = TransformField fn (_wrapGroup v')

{-| Takes an agg and wraps the extraction patterns so that it accesses inside
the group instead of the top-level field path.
-}
_wrapAgg :: AggOp -> AggOp
_wrapAgg (AggUdaf ua ucn fp) = AggUdaf ua ucn (_wrapFieldPath fp)
_wrapAgg (AggFunction sfn fp) = AggFunction sfn (_wrapFieldPath fp)
_wrapAgg (AggStruct v) = AggStruct (f <$> v) where
  f (AggField fn v') = AggField fn (_wrapAgg v')

_wrapFieldPath :: FieldPath -> FieldPath
_wrapFieldPath (FieldPath v) = FieldPath v' where
  v' = V.fromList (_value : V.toList v)

_groupType :: N.NonEmpty TypedColOp -> (ColOp, DataType)
_groupType l = (ColStruct (V.fromList (fst <$> l')), structType (snd <$> l')) where
  f ((co', dt'), idx) = (TransformField fname co', StructField fname dt') where
                fname = _keyIdx idx
  l' = f <$> ((N.toList l) `zip` [(1 :: Int)..])

-- TODO: this only works for less graupstack < 10
_keyIdx :: Int -> FieldName
_keyIdx idx = FieldName $ "key_" <> show' idx

-- Builds an extractor for a given key
_keyExtractor :: Int -> ColOp
_keyExtractor idx = ColExtraction . FieldPath . V.fromList $ [_key, _keyIdx idx]

_groupExtractor :: ColOp
_groupExtractor = ColExtraction . FieldPath . V.singleton $ _value

_convertTransform :: GroupStack -> (ColOp, DataType) -> (ColOp, DataType)
_convertTransform [] (co, dt) = (co, dt)
_convertTransform l (co, dt) =
  (ColStruct (V.fromList [keyF, groupF]), structType [keyDt, groupDt]) where
  groupF = TransformField _value co
  groupDt = structField "group" dt
  f ((co'', dt'), idx) = (TransformField fname co'', StructField fname dt') where fname = _keyIdx idx
  l' = f <$> (l `zip` [(1 :: Int)..])
  co' = ColStruct (V.fromList (fst <$> l'))
  keyDt = structField "key" $ structType (snd <$> l')
  keyF = TransformField _key co'

_key :: FieldName
_key = "key"

_value :: FieldName
_value = "value"

_getInterestingParent :: [((GroupStack, FNode), StructureEdge)] -> Try (GroupStack, [CoreNodeInfo])
_getInterestingParent l =
  let parents = filter ((ParentEdge ==) . snd) l
      stacks = nub (fst . fst <$> parents)
      f (FNode _ cni) = cni
      ops = f . snd . fst <$> parents
  in case stacks of
    [st] -> pure (st, ops)
    [] -> pure ([], ops) -- No key, which also works.
    _ -> tryError $ sformat ("_getInterestingParent: multiple parents have been found with different groups: "%sh) l

-- Checks if we are processing inside a group or in top level
-- This happens if any of the parent nodes is from a group.
_inTopLevel :: [((GroupStack, FNode), StructureEdge)] -> Bool
_inTopLevel [] = True
_inTopLevel (((_ : _, _), _) : _) = False
_inTopLevel ((([], _), _) : l) = _inTopLevel l
