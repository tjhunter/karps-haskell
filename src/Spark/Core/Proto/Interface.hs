{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
-- The communication protocol with the server

module Spark.Core.Proto.Computation where

import Data.Text(Text, pack)
import Data.Aeson
import Data.Aeson.Types(Parser)
import GHC.Generics

-- data CreateComputationRequest = CreateComputationRequest {
--   ccrSessionId :: SessionId
-- } deriving (Show, Generic)
