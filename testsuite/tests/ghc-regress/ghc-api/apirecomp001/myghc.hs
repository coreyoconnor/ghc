-- 1. Load a set of modules with "nothing" target
-- 2. Load it again with "interpreted" target
-- 3. Execute some code
--    a. If the recompilation checker is buggy this will die due to missing
--       code
--    b. If it's correct, it will recompile because the target has changed.
--
-- This program must be called with GHC's libdir as the single command line
-- argument.
module Main where

import GHC
import DynFlags
import MonadUtils ( MonadIO(..) )
import BasicTypes ( failed )
import Bag        ( bagToList )
import System.Environment
import Control.Monad
import System.IO

main = do
  [libdir] <- getArgs
  runGhc (Just libdir) $ do
    dflags <- getSessionDynFlags
    setSessionDynFlags $ dflags { hscTarget = HscNothing
                                , ghcLink  = LinkInMemory
                                , verbosity = 0 -- silence please
                                }
    root_mod <- guessTarget "A.hs" Nothing
    setTargets [root_mod]
    ok <- loadWithLogger myLogger LoadAllTargets
    when (failed ok) $ error "Couldn't load A.hs in nothing mode"
    prn "target nothing: ok"

    dflags <- getSessionDynFlags
    setSessionDynFlags $ dflags { hscTarget = HscInterpreted }
    ok <- loadWithLogger myLogger LoadAllTargets
    when (failed ok) $ error "Couldn't load A.hs in interpreted mode"
    prn "target interpreted: ok"

    -- set context to module "A"
    mg <- getModuleGraph
    let [mod] = [ ms_mod m | m <- mg, moduleNameString (ms_mod_name m) == "A" ]
    setContext [mod] []
    liftIO $ hFlush stdout  -- make sure things above are printed before
                            -- interactive output
    dflags <- getSessionDynFlags
    setSessionDynFlags $ flattenExtensionFlags dflags
    r <- runStmt "main" RunToCompletion
    case r of
      RunOk _        -> prn "ok"
      RunFailed      -> prn "compilation failed"
      RunException _ -> prn "exception"
      RunBreak _ _ _ -> prn "breakpoint"
    liftIO $ hFlush stdout
    return ()

-- prints number of warnings; this is our indicator for recompilation.  We ignore
-- the number of warnings since this might change, however, there should always
-- be at least one.
myLogger _ = do 
  ws <- getWarnings 
  clearWarnings
  liftIO $ print (length (bagToList ws) > 0)

prn :: MonadIO m => String -> m ()
prn = liftIO . putStrLn