const { tileNames } = require("./constants");
const { eById, eByClass, addClass, removeClass, isReverse, isVertical } = require("./utils");

const ROWS = 4;
const COLUMNS = 4;

let active;

const spaceAt = (packedSpaces, row, column) => 
  Number((BigInt(packedSpaces) >> BigInt((row * COLUMNS + column) * ROWS)) & BigInt(0xF));

module.exports = {
  ROWS, 
  COLUMNS,
  
  active: () => active,

  spaceAt,

  display: (board) => {
    const { packedSpaces } = board;
    const allColors = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13].map(i => `color${i}`);
    const tiles = eByClass('tile');
    let topTile = 1;
    for (let i=0; i<ROWS; ++i) {
      for (let j=0; j<COLUMNS; ++j) {
        const tile = spaceAt(packedSpaces, i, j);
        if (tile > topTile) {
          topTile = tile;
        }
        const tileElement = tiles[(i * ROWS) + j];
        removeClass(tileElement, allColors);
        if (tile === 0) {
          tileElement.innerHTML = ""
        } else {
          tileElement.innerHTML = `<div><div class='value'>${Math.pow(2, tile)}</div><div>${tileNames[tile]}</div></div>`;
          addClass(tileElement, `color${tile}`)
        }
      }
    }

    const scoreElement = eById('score');
    scoreElement.innerHTML = board.score;
    eById('score-result').innerHTML = board.score;
    
    const topTileElement = eById('top-tile');
    removeClass(topTileElement, allColors);
    addClass(topTileElement, `color${topTile}`);
    eById('top-tile-value').innerHTML = Math.pow(2, topTile);
    eById('top-tile-name').innerHTML = tileNames[topTile];

    if (board.gameOver) {
      removeClass(eById('error-game-over'), 'hidden');
    }

    active = board;
  },
  
  clear: () => {
    const tiles = eByClass('tile');
    for (const tile of tiles) {
      tile.innerHTML = "";
    }
  },

  diff: (packedSpaces1, packedSpaces2, direction) => {
    const reverse = isReverse(direction);
    const vertical = isVertical(direction);

    const tiles = {}

    const start = reverse ? COLUMNS - 1 : 0;
    const end = reverse ? 0 : COLUMNS - 1;
    const increment = reverse ? -1 : 1;

    for (let i=start; reverse ? i>=end : i<=end; i+=increment) {
      for (let j=start; reverse ? j>=end : j<=end; j+=increment) {
        let tile1 = spaceAt(packedSpaces1, i, j);
        const tile2 = spaceAt(packedSpaces2, i, j);
        const index = (i * COLUMNS) + j;

        if (tile2 !== 0) {
          if (tile1 === tile2) continue;

          const searchStart = (vertical ? i : j) + increment;
          for (let x=searchStart; reverse ? x>=end : x<=end; x+=increment) {
            const distance = Math.abs(vertical ? x - i : x - j);
            const nextTile = vertical ? spaceAt(packedSpaces1, x, j) : spaceAt(packedSpaces1, i, x);
            
            if (nextTile === 0) continue;
            
            // if (vertical) {
            //   spaces1[x][j] = null;
            // } else {
            //   spaces1[i][x] = null;
            // }
            
            const tile1Index = vertical ? (x * COLUMNS) + j : (i * COLUMNS) + x;
            tiles[tile1Index] = {
              [direction]: distance
            }

            if (nextTile === tile2 - 1) {
              tiles[index] = {
                merge: true
              }

              if (tile1 === null) {
                x = (vertical ? i : j) + increment;
                tile1 = tile2 - 1;
                continue;
              } 
            } 
            break;
          }
        }
      }
    }
    return tiles;
  },

  convertInfo: (board) => {
    const { 
      packed_spaces: packedSpaces, 
      // board_spaces: rawBoardSpaces, 
      last_tile: lastTile, 
      top_tile: topTile,
      score, 
      game_over: gameOver,
    } = board.fields || board.parsedJson || board;
    // const packedSpaces = (packedSpaces || rawBoardSpaces);
    return { 
      packedSpaces, 
      lastTile, 
      topTile: Number(topTile), 
      score: Number(score), 
      gameOver, 
    }
  }
}