class @ZoneGrid
  constructor: (min_x, max_x, min_y, max_y, scene) ->
    @min_x = -(min_x - 1)
    @max_x = -(max_x + 2)
    @min_y = min_y - 1
    @max_y = max_y + 2
    @scene = scene

    subdivisions = {
      w: @max_x - @min_x,
      h: @max_y - @min_y
    }
    lines = []
    for x in [@min_x..@max_x]
      path = []
      path.push(new BABYLON.Vector3(x, 0, @min_y))
      path.push(new BABYLON.Vector3(x, 0, @max_y))
      lines.push(path)
    for z in [@min_y..@max_y]
      path = []
      path.push(new BABYLON.Vector3(@min_x, 0, z))
      path.push(new BABYLON.Vector3(@max_x, 0, z))
      lines.push(path)
    grid = BABYLON.MeshBuilder.CreateLineSystem("zone_grid", {lines: lines}, @scene)
    grid.color = new BABYLON.Color3(0, 0, 0)

#    grid = BABYLON.MeshBuilder.CreateTiledGround("zone_grid", {xmin: @min_x, xmax: @max_x, zmin: @min_y, zmax: @max_y, subdivisions: subdivisions }, @scene)
#    grid.enableEdgesRendering()
#    grid.edgesWidth = 4.0
#    grid.edgesColor = new BABYLON.Color4(0, 0, 0, 1)
#    material = new BABYLON.StandardMaterial("zone_grid_material", @scene)
#    material.alpha = 0.0
#    grid.material = material
#
#    verticesCount = grid.getTotalVertices()
#    tileIndicesLength = grid.getIndices().length / (subdivisions.w * subdivisions.h)
#    grid.subMeshes = []
#    base = 0
#    for row in [0..subdivisions.h-1]
#      for col in [0..subdivisions.w-1]
#        grid.subMeshes.push(new BABYLON.SubMesh(row%2 ^ col%2, 0, verticesCount, base , tileIndicesLength, grid))
#        base += tileIndicesLength

    line = []
    line.push(new BABYLON.Vector3(0, 0, 1))
    line.push(new BABYLON.Vector3(0, 0, 0))
    origin = BABYLON.MeshBuilder.CreateTube("zone_grid_origin_indicator", {path: line, radius: 0.01}, @scene)
    origin.color = new BABYLON.Color3.Red()

    @object3d = grid