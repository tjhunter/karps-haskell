{-# LANGUAGE OverloadedStrings #-}

{-| The data structures for the server part -}
module Spark.Server.StructureParsing where

import Spark.Core.StructuresInternal
import Spark.Core.Dataset(UntypedNode)
import Spark.Core.Internal.TypesStructures(DataType)
import Spark.Core.Internal.TypesFunctions()
import Spark.Core.Internal.Client
import Spark.Core.Try

import Data.Text(Text, pack)
import Data.List.NonEmpty(NonEmpty)
import Data.Map.Strict(Map)
import Data.Aeson
import Data.Aeson.Types(Parser)
import GHC.Generics
import Spark.Proto.ApiInternal.PerformGraphTransform(PerformGraphTransform)
import Spark.Proto.ApiInternal.GraphTransformResponse(GraphTransformResponse)
import Spark.Server.Structures

{-| The main compiler function.

TODO: add the Spark options
-}
transform :: GraphTransform -> GraphTransformResult
transform = undefined
