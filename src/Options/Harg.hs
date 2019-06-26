{-# LANGUAGE PatternSynonyms #-}
module Options.Harg
  ( Opt
  , getParser
  , Single (..)
  , single
  , Nested (..)
  , nested
  , getNested

  , mkOpt
  , arg
  , argWith
  , flag
  , flagWith
  , switch
  , switchWith
  , switch'
  , switchWith'
  , optLong
  , optShort
  , optHelp
  , optMetavar
  , optEnvVar
  , optDefault

  , parseWith
  , readParser
  , strParser

  , execParserDef
  , execParserPureDef
  , execOpt
  , execOptPure

  , VariantF (..)
  , pattern In1
  , pattern In2
  , pattern In3
  , pattern In4
  , pattern In5

  , HListF (..)

  , AssocListF (..)

  , foldF

  , (:*)
  , pattern (:*)
  , (:+)
  , pattern (:+)
  , (:->)
  ) where

import           Options.Harg.Het.AssocList
import           Options.Harg.Het.HList
import           Options.Harg.Het.Variant
import           Options.Harg.Construct
import           Options.Harg.Helpers
import           Options.Harg.Operations
import           Options.Harg.Types
