{-| The registry of all the functions currently known to the program.
-}
module Spark.Server.Registry(
  structuredRegistry,
  nodeRegistry
) where

import Spark.Core.Internal.StructuredBuilder
import Spark.Core.Internal.NodeBuilder

-- TODO: fill the values
structuredRegistry :: StructuredBuilderRegistry
structuredRegistry = buildStructuredRegistry [] [] []

-- TODO: fill the values
nodeRegistry :: NodeBuilderRegistry
nodeRegistry = buildNodeRegistry []
