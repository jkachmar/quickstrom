{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module WebCheck.PureScript.AnalyzeTest where

import Control.Monad (Monad (fail))
import Protolude
import System.Environment (lookupEnv)
import Test.Tasty.Hspec hiding (Selector)
import WebCheck.Element
import WebCheck.PureScript.Program

loadModules :: IO Modules
loadModules = do
  let key = "WEBCHECK_LIBRARY_DIR"
  webcheckPursDir <-
    maybe (fail (key <> " environment variable is not set")) pure
      =<< lookupEnv key
  loadLibraryModules webcheckPursDir >>= \case
    Right ms -> pure ms
    Left err -> fail ("Failed to load modules: " <> toS err)

loadSpecificationProgram' :: FilePath -> Modules -> IO (Either Text SpecificationProgram)
loadSpecificationProgram' path modules = do
  code <- readFile path
  loadSpecification modules code

spec_analyze :: Spec
spec_analyze = beforeAll loadModules $ do
  it "extracts all queries when valid" $ \m -> do
    Right s <- loadSpecificationProgram' "test/WebCheck/PureScript/AnalyzeTest/Valid.purs" m
    specificationQueries s
      `shouldBe` [ ("p", [CssValue "display"]),
                   ("button", [Property "textContent"])
                 ]
  describe "rejects the specification when" $ do
    it "using queries with identifiers bound in let" $ \m -> do
      Left err <- loadSpecificationProgram' "test/WebCheck/PureScript/AnalyzeTest/FreeVariablesLocal.purs" m
      toS err `shouldContain` "Not in scope"

    it "using queries with identifiers bound at top level" $ \m -> do
      Left err <- loadSpecificationProgram' "test/WebCheck/PureScript/AnalyzeTest/FreeVariablesTopLevel.purs" m
      toS err `shouldContain` "Not in scope"

    it "constructing queries from results of other queries bound in let" $ \m -> do
      Left err <- loadSpecificationProgram' "test/WebCheck/PureScript/AnalyzeTest/DependentQueryLocal.purs" m
      toS err `shouldContain` "Queries cannot be"

    it "constructing queries from results of other queries bound at top level" $ \m -> do
      Left err <- loadSpecificationProgram' "test/WebCheck/PureScript/AnalyzeTest/DependentQueryTopLevel.purs" m
      toS err `shouldContain` "Queries cannot be"