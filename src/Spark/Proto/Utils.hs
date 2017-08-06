{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RankNTypes #-}
module Spark.Proto.Utils where

import Data.Text(Text, pack)
import Data.ProtocolBuffers
import Control.Monad.Trans.Error

newtype ProtoErrorMsg = ProtoErrorMsg Text

type ProtoTry t = Either ProtoErrorMsg t

instance Error ProtoErrorMsg where
  strMsg = ProtoErrorMsg . pack

protoFail :: Text -> ProtoTry t
protoFail = Left . ProtoErrorMsg

--pbExtract :: Text -> Optional x (z t) -> ProtoTry t
pbExtract :: forall a a1.
               (FieldType a ~ Maybe a1, HasField a) =>
               Text -> a -> ProtoTry a1
pbExtract msg x = case getField x of
  Just z -> pure z
  Nothing -> protoFail msg
