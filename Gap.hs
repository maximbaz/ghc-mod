{-# LANGUAGE CPP #-}

module Gap (
    supportedExtensions
  , getSrcSpan
  , getSrcFile
  , renderMsg
  , setCtx
  , fOptions
  , toStringBuffer
  , liftIO
#if __GLASGOW_HASKELL__ >= 702
#else
  , module Pretty
#endif
  ) where

import Control.Applicative hiding (empty)
import Control.Exception
import Control.Monad
import DynFlags
import FastString
import GHC
import Outputable
import StringBuffer

#if __GLASGOW_HASKELL__ >= 702
import CoreMonad (liftIO)
#else
import HscTypes (liftIO)
import Pretty
#endif

----------------------------------------------------------------
----------------------------------------------------------------

supportedExtensions :: [String]
#if __GLASGOW_HASKELL__ >= 700
supportedExtensions = supportedLanguagesAndExtensions
#else
supportedExtensions = supportedLanguages
#endif

----------------------------------------------------------------
----------------------------------------------------------------

getSrcSpan :: SrcSpan -> Maybe (Int,Int,Int,Int)
#if __GLASGOW_HASKELL__ >= 702
getSrcSpan (RealSrcSpan spn)
#else
getSrcSpan spn | isGoodSrcSpan spn
#endif
             = Just (srcSpanStartLine spn
                   , srcSpanStartCol spn
                   , srcSpanEndLine spn
                   , srcSpanEndCol spn)
getSrcSpan _ = Nothing

getSrcFile :: SrcSpan -> Maybe String
#if __GLASGOW_HASKELL__ >= 702
getSrcFile (RealSrcSpan spn)       = Just . unpackFS . srcSpanFile $ spn
#else
getSrcFile spn | isGoodSrcSpan spn = Just . unpackFS . srcSpanFile $ spn
#endif
getSrcFile _ = Nothing

----------------------------------------------------------------

renderMsg :: SDoc -> PprStyle -> String
#if __GLASGOW_HASKELL__ >= 702
renderMsg d stl = renderWithStyle d stl
#else
renderMsg d stl = Pretty.showDocWith PageMode $ d stl
#endif

----------------------------------------------------------------

toStringBuffer :: [String] -> Ghc StringBuffer
#if __GLASGOW_HASKELL__ >= 702
toStringBuffer = return . stringToStringBuffer . unlines
#else
toStringBuffer = liftIO . stringToStringBuffer . unlines
#endif

----------------------------------------------------------------

fOptions :: [String]
#if __GLASGOW_HASKELL__ == 702
fOptions = [option | (option,_,_,_) <- fFlags]
#else
fOptions = [option | (option,_,_) <- fFlags]
#endif

----------------------------------------------------------------
----------------------------------------------------------------

setCtx :: [ModSummary] -> Ghc Bool
#if __GLASGOW_HASKELL__ >= 704
setCtx ms = do
    top <- map (IIModule . ms_mod) <$> filterM isTop ms
    setContext top
    return (not . null $ top)
#else
setCtx ms = do
    top <- map ms_mod <$> filterM isTop ms
    setContext top []
    return (not . null $ top)
#endif
  where
    isTop mos = lookupMod `gcatch` returnFalse
      where
        lookupMod = lookupModule (ms_mod_name mos) Nothing >> return True
        returnFalse = constE $ return False

constE :: a -> (SomeException -> a)
constE func = \_ -> func
