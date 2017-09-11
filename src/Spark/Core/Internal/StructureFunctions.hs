{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}

{-| Low-level functions that relate to structured transforms.

This module implements the basic operators that form the big data
algebra:
 - shuffle (groupby of datasets -> datasets)
 - structured transform (map over datasets / columns)
 - local structured transform (map over observables)
 - structured reduce (datasets -> observables)

This module also contains some utilities for column operations.
-}
module Spark.Core.Internal.StructureFunctions(
  -- Low-level nodes
  shuffleBuilder,
  transformBuilder,
  localTransformBuilder,
  reduceBuilder,
  -- Functional nodes (high level)
  functionalShuffleBuilder,
  functionalTransformBuilder,
  functionalLocalTransformBuilder,
  functionalReduceBuilder
) where

import Control.Monad(when)
import Formatting

import Spark.Core.Internal.LocalDataFunctions()
import Spark.Core.Internal.TypesFunctions(structTypeFromFields, extractFields)
import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.OpFunctions(aggOpFromProto, colOpFromProto)
import Spark.Core.Internal.TypesStructures
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.StructuredBuilder
import Spark.Core.Internal.Utilities
import Spark.Core.Try
import Spark.Proto.Std(Shuffle(..), StructuredTransform(..), StructuredReduce(..))

{-| The low-level shuffle.

This operation should not be used directly by the users. Use the functional
builder instead. -}
shuffleBuilder :: StructuredBuilderRegistry -> NodeBuilder
shuffleBuilder reg = buildOpDExtra nameGroupedReduction $ \dt (Shuffle agg) -> do
  -- Check first that the dataframe has two columns.
  (keyDt, groupDt) <- _splitGroupType dt
  dt' <- StrictType . Struct <$> structTypeFromFields [("key", keyDt), ("group", groupDt)]
  -- Get the type after the grouping.
  ao <- aggOpFromProto agg
  aggDt <- aggTypeStructured reg ao dt'
  resDt <- StrictType . Struct <$> structTypeFromFields [("key", keyDt), ("group", aggDt)]
  return $ coreNodeInfo resDt Distributed (NodeGroupedReduction ao)

{-| The low-level dataset -> dataset structured transform builder.

Users should use the functional one instead.
-}
transformBuilder :: StructuredBuilderRegistry -> NodeBuilder
transformBuilder reg = buildOpDExtra nameStructuredTransform $ \dt (StructuredTransform col) -> do
  co <- colOpFromProto col
  resDt <- colTypeStructured reg co dt
  return $ coreNodeInfo resDt Distributed (NodeStructuredTransform co)

{-| The low-level observable -> observable structured transform builder.

Users should use the functional one instead.
-}
localTransformBuilder :: StructuredBuilderRegistry -> NodeBuilder
localTransformBuilder reg = buildOpLExtra nameLocalStructuredTransform $ \dt (StructuredTransform col) -> do
  co <- colOpFromProto col
  resDt <- colTypeStructured reg co dt
  return $ coreNodeInfo resDt Local (NodeLocalStructuredTransform co)

{-| The low-level dataset -> observable structured transform builder.

Users should use the functional one instead.
-}
reduceBuilder :: StructuredBuilderRegistry -> NodeBuilder
reduceBuilder reg = buildOpDExtra "org.spark.StructuredReduce" $ \dt (StructuredReduce agg) -> do
  ao <- aggOpFromProto agg
  resDt <- aggTypeStructured reg ao dt
  return $ coreNodeInfo resDt Local (NodeGroupedReduction ao)

{-| The functional shuffle builder.

This function takes another function (described as a computation graph)
to perform the transform.

This builder does not check the validity of the graph, just some basic input
and output characteristics.

The 3 arguments are:
 - the parent (distributed), on which to operate the transform
 - a placeholder (distributed), of same type as the parent
 - a dataset, which should be linked to the placeholder (not checked)
-}
functionalShuffleBuilder :: NodeBuilder
functionalShuffleBuilder = buildOp3 "org.spark.FunctionalShuffle" $ \ns1 ns2 ns3 -> do
  -- Split the input type into the key type and value type.
  dt <- _checkShuffle Distributed ns1 ns2 ns3
  return $ cniStandardOp Distributed "org.spark.FunctionalShuffle" dt ()

{-| The functional transform builder.

This builder takes another function (described as a computation graph)
to perform the transform.

This builder does not check the validity of the graph, just some basic input
and output characteristics.
-}
functionalTransformBuilder :: NodeBuilder
functionalTransformBuilder = buildOp3 "org.spark.FunctionalTransform" $ \ns1 ns2 ns3 -> do
  _check Distributed ns1 ns2 ns3
  return $ cniStandardOp Distributed "org.spark.FunctionalTransform" (nsType ns3) ()

{-| The functional transform builder, applied to local transforms.

This builder takes another function (described as a computation graph)
to perform the transform.

This builder does not check the validity of the graph, just some basic input
and output characteristics.
-}
functionalLocalTransformBuilder :: NodeBuilder
functionalLocalTransformBuilder = buildOp3 "org.spark.FunctionalLocalTransform" $ \ns1 ns2 ns3 -> do
  _check Local ns1 ns2 ns3
  return $ cniStandardOp Local "org.spark.FunctionalLocalTransform" (nsType ns3) ()

{-| The functional reduce builder.
-}
functionalReduceBuilder :: NodeBuilder
functionalReduceBuilder = buildOp3 "org.spark.FunctionalReduce" $ \ns1 ns2 ns3 -> do
  dt <- _checkShuffle Distributed ns1 ns2 ns3
  return $ cniStandardOp Local "org.spark.FunctionalReduce" dt ()

_splitGroupType :: DataType -> Try (DataType, DataType)
_splitGroupType dt = do
  l <- extractFields ["key", "group"] dt
  case l of
    [keyDt, groupDt] -> pure (keyDt, groupDt)
    _ -> tryError $ sformat ("Expected 2 fields, got "%sh%" from "%sh) l dt


_checkShuffle :: Locality -> NodeShape -> NodeShape -> NodeShape -> Try DataType
_checkShuffle loc ns1 ns2 ns3 = do
  (keyDt, groupDt) <- _splitGroupType (nsType ns1)
  when (groupDt /= nsType ns2) $
    tryError $ sformat ("_checkShuffle: expected two nodes of the same shape, but the second input "%sh%" does not match the shape of first node:"%sh) ns2 ns1
  when (nsLocality ns1 /= Distributed) $
    tryError $ sformat ("_checkShuffle: expected first input to be distributed: "%sh) ns1
  when (nsLocality ns2 /= Distributed) $
    tryError $ sformat ("_checkShuffle: expected second input to be distributed: "%sh) ns2
  when (nsLocality ns3 /= loc) $
    tryError $ sformat ("_checkShuffle: expected third input to be distributed: "%sh) ns3
  -- We cannot check if ns2 is a placeholder, it will be done during decomposition.
  t <- structTypeFromFields [("key", keyDt), ("group", nsType ns3)]
  return . StrictType . Struct $ t

_check :: Locality -> NodeShape -> NodeShape -> NodeShape -> Try ()
_check loc ns1 ns2 ns3 = do
  when (nsType ns1 /= nsType ns2) $
    tryError $ sformat ("_checkShuffle: expected two nodes of the same shape, but the second input "%sh%" does not match the shape of first node:"%sh) ns2 ns1
  when (nsLocality ns1 /= loc) $
    tryError $ sformat ("_checkShuffle: expected first input to be distributed: "%sh) ns1
  when (nsLocality ns2 /= loc) $
    tryError $ sformat ("_checkShuffle: expected second input to be distributed: "%sh) ns2
  when (nsLocality ns3 /= loc) $
    tryError $ sformat ("_checkShuffle: expected third input to be distributed: "%sh) ns3

_checkSameShape :: NodeShape -> NodeShape -> Try ()
_checkSameShape ns1 ns2 =
    if ns1 == ns2
    then return ()
    else tryError $ sformat ("_checkSameShape: expected two nodes of the same shape, but the second input "%sh%" does not match the shape of first node:"%sh) ns2 ns1
