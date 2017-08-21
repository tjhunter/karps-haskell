{-# LANGUAGE OverloadedStrings #-}

{-| This module contains data structures and functions to
build operator nodes, both in the DSL and the context of loading
and verifying graphs.
-}
module Spark.Core.Internal.NodeBuilder(
  BuilderFunction,
  NodeBuilder(..),
  buildOpExtra,
  buildOp1,
  buildOp2,
  buildOpD,
  buildOpL,
  buildOpDD,
  buildOpDL,
  cniStandardOp
) where

import qualified Data.Aeson as A
import Data.Text(Text)
import Data.Text.Encoding(encodeUtf8)

import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Try
import Spark.Proto.Graph.All(OpExtra(..))

{-| Function that describes how to build a node, given some extra
data (which may be empty) and a context of all the parents' shapes.
-}
type BuilderFunction = OpExtra -> [NodeShape] -> Try CoreNodeInfo

{-| Describes how to build a node.
-}
data NodeBuilder = NodeBuilder {
  nbName :: !Text,
  nbBuilder :: !BuilderFunction
}

{-| This is the typed interface to building nodes.

This allows developers to properly define a schema to the content.
-}
data TypedNodeBuilder a = TypedNodeBuilder !Text (a -> [NodeShape] -> Try CoreNodeInfo)


buildOpExtra :: A.FromJSON a => Text -> (a -> Try CoreNodeInfo) -> NodeBuilder
buildOpExtra opName f = untypedBuilder $ TypedNodeBuilder opName f' where
  f' a [] = f a
  f' _ l = fail $ "buildOpExtra: " ++ show opName ++ ": got extra parents: " ++ show l

{-| Takes one argument, no extra.
-}
buildOp1 :: Text -> (NodeShape -> Try CoreNodeInfo) -> NodeBuilder
buildOp1 opName f = NodeBuilder opName f' where
  f' _ [] = fail $ "buildOp1: " ++ show opName ++ ": missing parents "
  f' _ [ns] = f ns
  f' _ l = fail $ "buildOp1: " ++ show opName ++ ": got extra parents: " ++ show l

{-| Takes one argument, no extra.
-}
buildOp2 :: Text -> (NodeShape -> NodeShape -> Try CoreNodeInfo) -> NodeBuilder
buildOp2 opName f = NodeBuilder opName f' where
  f' _ [] = fail $ "buildOp2: " ++ show opName ++ ": missing parents "
  f' _ [ns1, ns2] = f ns1 ns2
  f' _ l = fail $ "buildOp2: " ++ show opName ++ ": got extra parents: " ++ show l

{-| Takes one dataframe, no extra.
-}
buildOpD :: Text -> (DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpD opName f = buildOp1 opName f' where
  f' (NodeShape dt Local) = fail $ "buildOpD: " ++ show opName ++ ": expected distributed node, but got a local node of type " ++ show dt ++ " instead."
  f' (NodeShape dt Distributed) = f dt

{-| Takes two dataframes, no extra.
-}
buildOpDD :: Text -> (DataType -> DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpDD opName f = buildOp2 opName f' where
  f' (NodeShape dt1 Distributed) (NodeShape dt2 Distributed) = f dt1 dt2
  f' ns1 ns2 = fail $ "buildOpDD: " ++ show opName ++ ": expected two distributed nodes, but got a local node of type: " ++ show (ns1, ns2)

{-| Takes one dataframe, one local, no extra.
-}
buildOpDL :: Text -> (DataType -> DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpDL opName f = buildOp2 opName f' where
  f' (NodeShape dt1 Distributed) (NodeShape dt2 Local) = f dt1 dt2
  f' ns1 ns2 = fail $ "buildOpDL: " ++ show opName ++ ": expected two nodes (Distributed, Local), but got another combination node of type: " ++ show (ns1, ns2)

{-| Takes one observable, no extra.
-}
buildOpL :: Text -> (DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpL opName f = buildOp1 opName f' where
  f' (NodeShape dt Local) = f dt
  f' (NodeShape dt Distributed) = fail $ "buildOpD: " ++ show opName ++ ": expected local node, but got a distributed node of type " ++ show dt ++ " instead."

{-| Converts a typed builder to an untyped builder.
-}
untypedBuilder :: A.FromJSON a => TypedNodeBuilder a -> NodeBuilder
untypedBuilder (TypedNodeBuilder n f) = NodeBuilder n (_convertTyped f)

cniStandardOp :: A.ToJSON a => Locality -> Text -> DataType -> a -> CoreNodeInfo
cniStandardOp loc opName dt extra = CoreNodeInfo {
    cniShape = NodeShape {
      nsType = dt,
      nsLocality = loc
    },
    cniOp = NodeDistributedOp StandardOperator {
      soName = opName,
      soOutputType = dt,
      soExtra = A.toJSON extra
    }
  }


_convertTyped :: A.FromJSON a => (a -> [NodeShape] -> Try CoreNodeInfo) -> BuilderFunction
_convertTyped f (OpExtra (Just s)) l = do
  let bs = encodeUtf8 s
  case A.eitherDecodeStrict' bs of
    Right x -> f x l
    Left msg -> fail $ "buildOp0: parsing of arguments failed: " ++ show msg
_convertTyped _ (OpExtra Nothing) _ = fail "buildOp0: missing extra info"
