import 'ResizeObserver'
import 'babylonjs'
import 'babylonjs-gui'
import 'babylonjs-inspector'
import ArcRotateCameraOrthographicMouseWheelInput from './ArcRotateCameraOrthographicMouseWheelInput'
import HUD from './hud'
import EnclosureRacksManager from './enclosure_racks_manager'

export default class VisualDC
  constructor: ->
    @camera = null
    @engine = null
    @scene = null
    @zone_grid = null
    @enclosure_racks_manager = null
    @hud = null

    $(document).on 'turbolinks:load', =>
      @initializeVisualDC()
    $(document).on 'turbolinks:before-cache', =>
      @destroyVisualDC()

  resizeVisualDC: =>
    return unless @getCanvas().length
    canvasDom = @getCanvas().get(0)
    @engine.resize()
    if @camera instanceof Object
      scale = 100
      @camera.orthoLeft = -canvasDom.width / scale
      @camera.orthoRight = canvasDom.width / scale
      @camera.orthoBottom = -canvasDom.height / scale
      @camera.orthoTop = canvasDom.height / scale

  setCameraMode: (mode) ->
    @camera.mode = mode
    if mode == BABYLON.Camera.ORTHOGRAPHIC_CAMERA
      @camera.inputs.removeByType("ArcRotateCameraMouseWheelInput")
      @camera.inputs.add(new ArcRotateCameraOrthographicMouseWheelInput())
    else
      @camera.inputs.removeByType("ArcRotateCameraOrthographicMouseWheelInput")
      @camera.inputs.add(new BABYLON.ArcRotateCameraMouseWheelInput())

  getCanvas: ->
    return $('#visual_dc_canvas')

  initializeVisualDC: ->
    canvasDom = @getCanvas().get(0)
    return unless $(canvasDom).length
    @resize_observer = new ResizeObserver(@resizeVisualDC)
    @resize_observer.observe(canvasDom)
    @engine = new BABYLON.Engine(canvasDom, true)
    @scene = new BABYLON.Scene(@engine)
    @scene.clearColor = new BABYLON.Color3(229/256, 230/256, 231/256)
    @scene.debugLayer.show()

    canvasDom.setAttribute("oncontextmenu", "return false")

    @camera = new BABYLON.ArcRotateCamera("Camera", Math.PI / 2, 15 * Math.PI / 32, 25, BABYLON.Vector3.Zero(), @scene)
    @camera.panningSensibility = 500
    @camera.attachControl(canvasDom, true, false)
    @resizeVisualDC()
    #@setCameraMode(BABYLON.Camera.PERSPECTIVE_CAMERA)
    @setCameraMode(BABYLON.Camera.ORTHOGRAPHIC_CAMERA)

    #ambientLight = new BABYLON.HemisphericLight('ambientLight', new BABYLON.Vector3.Zero(), @scene)
    frontDirectionalLight = new BABYLON.DirectionalLight('frontDirectionalLight', new BABYLON.Vector3(0.5, -0.75, 1), @scene)
    backDirectionalLight = new BABYLON.DirectionalLight('backDirectionalLight', new BABYLON.Vector3(-0.5, -0.75, -1), @scene)
  
    @hud = new HUD(@)
    @enclosure_racks_manager = new EnclosureRacksManager(@)
    @enclosure_racks_manager.populate()

    #BABYLON.SceneOptimizer.OptimizeAsync(@scene, BABYLON.SceneOptimizerOptions.ModerateDegradationAllowed())
  
    @engine.runRenderLoop =>
      @scene.render()

  destroyVisualDC: ->
    return unless @getCanvas().length
    @resize_observer.disconnect()
    @scene.dispose()