{-| The registry of all the functions currently known to the program.
-}
module Spark.Server.Registry(
  structuredRegistry,
  nodeRegistry
) where

import Spark.Core.Internal.StructuredBuilder
import Spark.Core.Internal.NodeBuilder
import Spark.Core.Internal.DatasetStd
import Spark.Core.Internal.Joins
import Spark.Core.Internal.StructureFunctions

-- TODO: fill the values
structuredRegistry :: StructuredBuilderRegistry
structuredRegistry = buildStructuredRegistry [] [] []

-- TODO: fill the values
nodeRegistry :: NodeBuilderRegistry
nodeRegistry = buildNodeRegistry [
  broadcastPairBuilder,
  functionalShuffleBuilder,
  functionalTransformBuilder,
  functionalLocalTransformBuilder,
  functionalReduceBuilder,
  identityBuilderD,
  identityBuilderL,
  -- joinBuilder,
  literalBuilderD,
  localTransformBuilder structuredRegistry,
  placeholderBuilder,
  pointerBuilder,
  reduceBuilder structuredRegistry,
  shuffleBuilder structuredRegistry,
  transformBuilder structuredRegistry]
