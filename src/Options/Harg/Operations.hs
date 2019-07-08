{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ConstraintKinds #-}
module Options.Harg.Operations where

import           Data.Functor.Compose       (Compose(..))
import           Data.Functor.Const         (Const(..))
import           Data.Functor.Identity      (Identity(..))
import           Data.Kind                  (Type, Constraint)
import           System.Environment         (getArgs)

import qualified Data.Barbie                as B
import qualified Options.Applicative        as Optparse

import           Options.Harg.Cmdline       (mkOptparseParser)
import           Options.Harg.Het.AssocList
import           Options.Harg.Het.Variant
import           Options.Harg.Het.Nat
import           Options.Harg.Parser
import           Options.Harg.Pretty
import           Options.Harg.Sources
import           Options.Harg.Types
import           Options.Harg.Util


execParserDef
  :: Parser a
  -> Optparse.Parser b
  -> IO (a, b)
execParserDef p extra
  = do
      args <- getArgs
      let (res, errs) = execParserDefPure p args extra
      case res of
        Optparse.Success a
          -> ppWarning errs >> pure a
        _
          -> ppError errs >> Optparse.handleParseResult res

execParserDefPure
  :: Parser a
  -> [String]
  -> Optparse.Parser b
  -> (Optparse.ParserResult (a, b), [OptError])
execParserDefPure (Parser parser err) args extra
  = let
      parserInfo
        = Optparse.info (Optparse.helper <*> ((,) <$> parser <*> extra)) Optparse.forwardOptions
      res
        = Optparse.execParserPure Optparse.defaultPrefs parserInfo args

    in (res, err)

-- getOptparseParser
--   :: GetParser a
--   => a
--   -> IO (Optparse.Parser (OptResult a))
-- getOptparseParser a
--   = do
--       sources <- getSources
--       getOptparseParserPure sources a

-- getOptparseParserPure
--   :: GetParser a
--   => [ParserSource]
--   -> a
--   -> IO (Optparse.Parser (OptResult a))
-- getOptparseParserPure sources a
--   = fst <$> getOptparseParserAndErrorsPure sources a

-- getOptparseParserAndErrors
  -- :: GetParser a
  -- => a
  -- -> IO (Optparse.Parser (OptResult a), [OptError])
-- getOptparseParserAndErrors a
  -- = do
      -- sources <- getSources
      -- pure $ getOptparseParserAndErrorsPure sources a

-- getOptparseParserAndErrorsPure
--   :: GetParser a
--   => [ParserSource]
--   -> a
--   -> IO (Optparse.Parser (OptResult a), [OptError])
-- getOptparseParserAndErrorsPure sources a
--   = do Parser p err <- getParser sources a
--        pure (p, err)

execOpt'
  :: forall c a.
     ( B.TraversableB a
     , B.ProductB a
     , B.TraversableB c
     , B.ProductB c
     , GetSources c Identity
     , RunSource (SourceVal c) a
     )
  => c Opt
  -> a Opt
  -> IO (a Identity)
execOpt' c a
  = do
      parser <- mkOptparseParser [] (compose Identity c)
      dummyParser <- mkOptparseParser [] (toDummyOpts @String a)
      let allParser = (,) <$> parser <*> dummyParser
      (yes, _notyet)
        <- Optparse.execParser
             (Optparse.info (Optparse.helper <*> allParser) mempty)
      sourceVals <- getSources' yes
      let (errs, sources) = accumSourceResults $ runSource' sourceVals a
      -- (errs, sources) <- getSources' yes a
      p <- getOptParser sources a
      (res, _) <- execParserDef (Parser p errs) parser
      pure res

execOptS
  :: forall c ts xs.
     ( B.TraversableB (VariantF xs)
     , B.TraversableB c
     , B.ProductB c
     , GetSources c Identity
     , All (RunSource (SourceVal c)) xs
     , All (RunSource '[]) xs
     , Subcommands Z ts xs '[]
     , DummySubcommands Z ts xs '[]
     , Show (c Identity)
     , MapAssocList xs
     , All' Show (SourceVal c)
     )
  => c Opt
  -> AssocListF ts xs Opt
  -> IO (VariantF xs Identity)
execOptS c a = do
  parser <- mkOptparseParser [] (compose Identity c)
  dummyCommands <- mapDummySubcommand @Z @ts @xs @'[] SZ (allToDummyOpts @String a)
  let
    dummyParser
      = Optparse.subparser (mconcat dummyCommands)
    allParser = (,) <$> parser <*> dummyParser
  (yes, _notyet)
    <- Optparse.execParser
         (Optparse.info (Optparse.helper <*> allParser) mempty)
  -- print yes
  sourceVals <- getSources' yes
  -- print sourceVals
  realCommands <- mapSubcommand @Z @ts @xs @'[] SZ sourceVals a
  let
    realParser
      = Optparse.subparser (mconcat realCommands)
  (res, _) <- execParserDef (Parser realParser []) parser
  pure res

class MapAssocList (as :: [(Type -> Type) -> Type]) where
  mapAssocList :: (forall a. B.FunctorB a => a f -> a g) -> AssocListF ts as f -> AssocListF ts as g

instance MapAssocList '[] where
  mapAssocList _ ANil = ANil

instance (MapAssocList as, B.FunctorB a) => MapAssocList (a ': as) where
  mapAssocList f (ACons x xs) = ACons (f x) (mapAssocList f xs)


allToDummyOpts
  :: forall m ts xs.
     ( Monoid m
     , MapAssocList xs
     )
  => AssocListF ts xs Opt
  -> AssocListF ts xs (Compose Opt (Const m))
allToDummyOpts
  = mapAssocList toDummyOpts

toDummyOpts
  :: forall m a.
     ( B.FunctorB a
     , Monoid m
     )
  => a Opt
  -> a (Compose Opt (Const m))
toDummyOpts
  = B.bmap toDummy
  where
    toDummy opt@Opt{..}
      = Compose
      $ Const
      <$> opt
            { _optDefault = Just mempty
            , _optReader  = pure . const mempty
            , _optType
                = case _optType of
                    OptionOptType   -> OptionOptType
                    FlagOptType _   -> FlagOptType mempty
                    ArgumentOptType -> ArgumentOptType
            }

-- execOpt
--   :: GetParser a
--   => a
--   -> IO (OptResult a)
-- execOpt a
--   = do
--       sources <- getSources
--       execParserDef =<< getParser sources a

-- execOptPure
--   :: GetParser a
--   => [String]
--   -> [ParserSource]
--   -> a
--   -> IO (Optparse.ParserResult (OptResult a), [OptError])
-- execOptPure args sources a
--   = do
--       p <- getParser sources a
--       pure $ execParserDefPure p args

