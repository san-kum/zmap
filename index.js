var gl = null;
var memory = null;
var vaos = [];
var programs = [];

function loadShader(gl, type, source) {
  const shader = gl.createShader(type);

  gl.shaderSource(shader, source);

  gl.compileShader(shader);

  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    console.log(
      `An error occurred compiling the shaders: ${gl.getShaderInfoLog(shader)}`,
    );
    gl.deleteShader(shader);
    return null;
  }

  return shader;
}

function compileLinkProgramWasm(vs, vs_len, fs, fs_len) {
  programs.forEach((program) => gl.deleteProgram(program));
  programs.length = 0;

  const vs_source = new Uint8Array(memory.buffer, vs, vs_len);
  const fs_source = new Uint8Array(memory.buffer, fs, fs_len);
  const dec = new TextDecoder("utf-8");
  const program = compileLinkProgram(
    dec.decode(vs_source),
    dec.decode(fs_source),
  );
  programs.push(program);
  return programs.length - 1;
}

function compileLinkProgram(vertex_source, fragment_source) {
  const vertexShader = loadShader(gl, gl.VERTEX_SHADER, vertex_source);
  const fragmentShader = loadShader(gl, gl.FRAGMENT_SHADER, fragment_source);

  const shaderProgram = gl.createProgram();
  gl.attachShader(shaderProgram, vertexShader);
  gl.attachShader(shaderProgram, fragmentShader);
  gl.linkProgram(shaderProgram);

  if (!gl.getProgramParameter(shaderProgram, gl.LINK_STATUS)) {
    alert(
      `Unable to initialize the shader program: ${gl.getProgramInfoLog(
        shaderProgram,
      )}`,
    );
  }
  return shaderProgram;
}

function bind2DFloatDataWasm(data, len) {
  vaos.forEach((vao) => gl.deleteVertexArray(vao));
  vaos.length = 0;
  const arr = new Float32Array(memory.buffer, data, len);
  vaos.push(bind2DFloatData(arr));
  return vaos.length - 1;
}

function bind2DFloatData(positions) {
  const positionBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
  gl.bufferData(gl.ARRAY_BUFFER, positions, gl.STATIC_DRAW);

  const vao = gl.createVertexArray();
  gl.bindVertexArray(vao);
  const vertexInfo = 0;
  const numComponents = 2;
  const type = gl.FLOAT;
  const normalize = false;
  const stride = 0;
  const offset = 0;

  gl.vertexAttribPointer(
    vertexInfo,
    numComponents,
    type,
    normalize,
    stride,
    offset,
  );
  gl.enableVertexAttribArray(vertexInfo);
  return vao;
}

async function init() {
  if (gl) {
    vaos.forEach((vao) => gl.deleteVertexArray(vao));
    programs.forEach((program) => gl.deleteProgram(program));
    vaos.length = 0;
    programs.length = 0;
  }
  const canvas = document.getElementById("canvas");
  gl = canvas.getContext("webgl2");
  if (gl === null) {
    console.error("Unable to find WebGL");
    return;
  }
  try {
    const mod = await WebAssembly.instantiateStreaming(
      fetch("./zig-out/bin/index.wasm"),
      {
        env: {
          compileLinkProgram: compileLinkProgramWasm,
          bind2DFloatData: bind2DFloatDataWasm,
          glBindVertexArray: (vao) => {
            gl.bindVertexArray(vaos[vao]);
          },
          glClearColor: gl.clearColor.bind(gl),
          glClear: gl.clear.bind(gl),
          glUseProgram: (program) => {
            gl.useProgram(programs[program]);
          },
          glDrawArrays: gl.drawArrays.bind(gl),
        },
      },
    );

    memory = mod.instance.exports.memory;

    mod.instance.exports.run();
    // requestAnimationFrame(render);
  } catch (error) {
    console.error("WebAssembly initialization failed.", error);
  }
}

window.addEventListener("load", init);
window.addEventListener("resize", init);
