{-# LANGUAGE OverloadedStrings #-}

{-| This module contains data structures and functions to
build operator nodes, both in the DSL and the context of loading
and verifying graphs.
-}
module Spark.Core.Internal.NodeBuilder(
  BuilderFunction,
  NodeBuilder(..),
  -- Basic tools
  cniStandardOp,
  cniStandardOp',
  -- No parent
  buildOpExtra,
  -- One parent
  buildOp1,
  buildOp1Extra,
  buildOpD,
  buildOpDExtra,
  buildOpL,
  buildOpLExtra,
  -- Two parents
  buildOp2,
  buildOp2Extra,
  buildOpDD,
  buildOpDDExtra,
  buildOpDL,
  -- Three parents
  buildOp3,
) where

import Data.Text(Text)
import Data.ProtoLens.Message(Message)
import Data.ProtoLens.Encoding(decodeMessage, encodeMessage)

import Spark.Core.Internal.OpStructures
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Try

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


buildOpExtra :: Message a => Text -> (a -> Try CoreNodeInfo) -> NodeBuilder
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

buildOp1Extra :: Message a => Text -> (NodeShape -> a -> Try CoreNodeInfo) -> NodeBuilder
buildOp1Extra opName f = untypedBuilder $ TypedNodeBuilder opName f' where
  f' _ [] = fail $ "buildOp1Extra: " ++ show opName ++ ": missing parents "
  f' a [ns] = f ns a
  f' _ l = fail $ "buildOp1Extra: " ++ show opName ++ ": got extra parents: " ++ show l

{-| Takes one argument, no extra.
-}
buildOp2 :: Text -> (NodeShape -> NodeShape -> Try CoreNodeInfo) -> NodeBuilder
buildOp2 opName f = NodeBuilder opName f' where
  f' _ [] = fail $ "buildOp2: " ++ show opName ++ ": missing parents "
  f' _ [ns1, ns2] = f ns1 ns2
  f' _ l = fail $ "buildOp2: " ++ show opName ++ ": got extra parents: " ++ show l

buildOp2Extra :: Message a => Text -> (NodeShape -> NodeShape -> a -> Try CoreNodeInfo) -> NodeBuilder
buildOp2Extra opName f = untypedBuilder $ TypedNodeBuilder opName f' where
  f' _ [] = fail $ "buildOp2Extra: " ++ show opName ++ ": missing parents "
  f' a [ns1, ns2] = f ns1 ns2 a
  f' _ l = fail $ "buildOp2Extra: " ++ show opName ++ ": got extra parents: " ++ show l

{-| Takes one argument, no extra.
-}
buildOp3 :: Text -> (NodeShape -> NodeShape -> NodeShape -> Try CoreNodeInfo) -> NodeBuilder
buildOp3 opName f = NodeBuilder opName f' where
  f' _ [ns1, ns2, ns3] = f ns1 ns2 ns3
  f' _ l = fail $ "buildOp3: " ++ show opName ++ ": expected 3 parent nodes, but got: " ++ show l

{-| Takes one dataframe, no extra.
-}
buildOpD :: Text -> (DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpD opName f = buildOp1 opName f' where
  f' (NodeShape dt Local) = fail $ "buildOpD: " ++ show opName ++ ": expected distributed node, but got a local node of type " ++ show dt ++ " instead."
  f' (NodeShape dt Distributed) = f dt

buildOpDExtra :: Message a => Text -> (DataType -> a -> Try CoreNodeInfo) -> NodeBuilder
buildOpDExtra opName f = buildOp1Extra opName f' where
  f' (NodeShape dt Local) = fail $ "buildOpDExtra: " ++ show opName ++ ": expected distributed node, but got a local node of type " ++ show dt ++ " instead."
  f' (NodeShape dt Distributed) = f dt

{-| Takes two dataframes, no extra.
-}
buildOpDD :: Text -> (DataType -> DataType -> Try CoreNodeInfo) -> NodeBuilder
-- TODO check that there is no extra
buildOpDD opName f = buildOp2 opName f' where
  f' (NodeShape dt1 Distributed) (NodeShape dt2 Distributed) = f dt1 dt2
  f' ns1 ns2 = fail $ "buildOpDD: " ++ show opName ++ ": expected two distributed nodes, but got a local node of type: " ++ show (ns1, ns2)

{-| Takes two dataframes, with extra.
-}
buildOpDDExtra :: (Message a) => Text -> (DataType -> DataType -> a -> Try CoreNodeInfo) -> NodeBuilder
buildOpDDExtra opName f = buildOp2Extra opName f' where
  f' (NodeShape dt1 Distributed) (NodeShape dt2 Distributed) x = f dt1 dt2 x
  f' ns1 ns2 _ = fail $ "buildOpDD: " ++ show opName ++ ": expected two distributed nodes, but got a local node of type: " ++ show (ns1, ns2)


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

buildOpLExtra :: Message a => Text -> (DataType -> a -> Try CoreNodeInfo) -> NodeBuilder
buildOpLExtra opName f =buildOp1Extra opName f' where
  f' (NodeShape dt Distributed) = fail $ "buildOpLExtra: " ++ show opName ++ ": expected local node, but got a distributed node of type " ++ show dt ++ " instead."
  f' (NodeShape dt Local) = f dt


{-| Converts a typed builder to an untyped builder.
-}
untypedBuilder :: Message a => TypedNodeBuilder a -> NodeBuilder
untypedBuilder (TypedNodeBuilder n f) = NodeBuilder n (_convertTyped f)

cniStandardOp :: Message a => Locality -> Text -> DataType -> a -> CoreNodeInfo
cniStandardOp loc opName dt extra = CoreNodeInfo {
    cniShape = NodeShape {
      nsType = dt,
      nsLocality = loc
    },
    cniOp = NodeDistributedOp StandardOperator {
      soName = opName,
      soOutputType = dt,
      soExtra = OpExtra $ encodeMessage extra
    }
  }

{-| Builds a standard operator node that does not take extra arguments. -}
cniStandardOp' :: Locality -> Text -> DataType -> CoreNodeInfo
cniStandardOp' loc opName dt = CoreNodeInfo {
    cniShape = NodeShape {
      nsType = dt,
      nsLocality = loc
    },
    cniOp = NodeDistributedOp StandardOperator {
      soName = opName,
      soOutputType = dt,
      soExtra = emptyExtra
    }
  }


_convertTyped :: Message a => (a -> [NodeShape] -> Try CoreNodeInfo) -> BuilderFunction
_convertTyped _ (OpExtra s) _ | s == "" = fail "buildOp0: missing extra info"
_convertTyped f (OpExtra s) l =
  case decodeMessage s of
    Right x -> f x l
    Left msg -> fail $ "buildOp0: parsing of arguments failed: " ++ show msg
