{-# LANGUAGE RecordWildCards, NamedFieldPuns #-}
module HCraft.Craft
  ( engine
  ) where

import           Control.Monad
import           Control.Monad.Error
import           Control.Monad.Reader
import           Control.Monad.Loops
import           Data.IORef
import qualified Data.Vector.Mutable as Vector
import           Graphics.UI.GLFW
import           Graphics.Rendering.OpenGL
import           HCraft.Engine
import           HCraft.Math
import           HCraft.Renderer
import           HCraft.World.Camera
import           HCraft.World.Chunk

create :: Engine ()
create = do
  EngineState{..} <- ask

  -- Initialise GLEW
  success <- liftIO $ do
    initialize

    openWindowHint OpenGLProfile       OpenGLCoreProfile
    openWindowHint OpenGLForwardCompat True
    openWindowHint OpenGLVersionMajor  4
    openWindowHint OpenGLVersionMinor  2

    size <- get esSize
    ret <- openWindow size [ DisplayAlphaBits 8 ] Window
    windowTitle $= "HCraft"
    disableSpecial MouseCursor

    return ret

  unless success $
    fail "Cannot create window"

  -- Initialise resources
  mapM_ buildTexture textureBuiltin
  mapM_ buildMesh meshBuiltin
  mapM_ buildProgram progBuiltin

  -- Initialise the renderer
  liftIO $ do
    depthFunc $= Just Lequal
    cullFace $= Just Back

    [ dfrFBO, shadowFBO, fxFBO ] <- genObjectNames 3

    esDfrFBO    $= Just dfrFBO
    esShadowFBO $= Just shadowFBO
    esFxFBO     $= Just fxFBO


loop :: Engine ()
loop = do
  EngineState{..} <- ask

  -- Keep track of time
  lastFrame <- liftIO $ (get time >>= newIORef)

  -- We need to quit at some point...
  liftIO $ windowCloseCallback $= do
    esRunning $= False
    return True

  -- Main loop
  whileM_ (liftIO . get $ esRunning) $ do
    -- Compute how many seconds were spent rendering the last frame
    dt <- liftIO $ do
      currentFrame <- get time
      time <- get lastFrame
      lastFrame $= currentFrame
      return (realToFrac $ currentFrame - time)

    -- Update stuff
    updateCamera dt
    updateTextures

    -- Render stuff
    renderSky
    renderChunks (Vec3 0 4 0)
    renderEntitities

    liftIO $ do
      size <- get windowSize
      viewport $= ( Position 0 0, size )
      swapBuffers
      clear [ DepthBuffer ]

destroy :: Engine ()
destroy =
  liftIO $ closeWindow >> terminate

engine :: Engine ()
engine
  = create >> loop >> destroy