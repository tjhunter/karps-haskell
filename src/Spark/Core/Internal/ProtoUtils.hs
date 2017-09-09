{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Spark.Core.Internal.ProtoUtils(ToProto(..), FromProto(..), extractMaybe, extractMaybe') where

import Data.ProtoLens.Message(Message(descriptor), MessageDescriptor(messageName))
import Lens.Family2 ((^.), FoldLike)
import Formatting
import Data.Text(Text)

import Spark.Core.Try(Try, tryError)

{-| The class of types that can be read from a proto description. -}
class FromProto p x | x -> p where
  fromProto :: (Message p) => p -> Try x

{-| The class of types that can be exported to a proto type. -}
class ToProto p x | x -> p where
  toProto :: (Message p) => x -> p

extractMaybe :: forall m a1 a' b. (Message m) => m -> FoldLike (Maybe a1) m a' (Maybe a1) b -> Text -> Try a1
extractMaybe msg fun ctx =
  case msg ^. fun of
    Just x' -> return x'
    Nothing -> tryError $ sformat ("extractMaybe: extraction failed in context "%shown%" for message "%shown) ctx txt where
      d = descriptor :: MessageDescriptor m
      txt = messageName d

extractMaybe' :: (Message m, Message m1, FromProto m1 a1) => m -> FoldLike (Maybe m1) m a' (Maybe m1) b -> Text -> Try a1
extractMaybe' msg fun ctx = extractMaybe msg fun ctx >>= fromProto