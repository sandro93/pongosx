/*
123333
  Copyright (C) 2014 Sergi Pasoev.

  This pragram is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or (at
  your option) any later version.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <http://www.gnu.org/licenses/>.

  spasoev at gmail.com

*/

#include "pong.h"
#include "multiplayer.h"
#include "SDL_thread.h"

#define WINDOW_TITLE "Pong"
#define FPS 70
#define INITIAL_SPEED 2.0
#define REQUIRED_HITS 5

#define SCORE_PER_HIT 10

int running = 1;
int window_width = 320;
int window_height = 480;
int stateChanged = 1;
int listener_d;
int connect_d;

typedef struct {
    
    Ball *ball;
    
    Player *player;
    
    Player *enemy;
    
} params;



int UpdateThread(void *arg)

{
    
    params *p = (params*)arg;
    
    
    
    while (running) {
        
        update(p->player, p->enemy, p->ball);
        
    }
    
    
    
    return 1;
    
}


int HandleThread(void *arg)

{
    SDL_mutex *mutex;
    
    mutex = SDL_CreateMutex();
    
    if (!mutex) {
        return 1;
    }
    
    //if (SDL_LockMutex(mutex) == 0) {
        while (running) {
        
            if (SDL_LockMutex(mutex) == 0) {
            
                char buff[255];
            
                sprintf(buff, "%.2f\0", ((Player *)arg)->x);
            
                if(!stateChanged) {
                    continue;
                }
            
            
                if (SERVER) {
                    say(connect_d, buff);
                } else {
                say(listener_d, buff);
                }
            
                SDL_UnlockMutex(mutex);
                
                // say(listener_d, "180.00\0");
                SDL_Delay(5);
                                
            }
            
        }
        
        //SDL_UnlockMutex(mutex);
    //}
    
    SDL_DestroyMutex(mutex);
    
    
    return 1;
    
}


int main(int  argc, char** argv){

  // create window
  SDL_Window *window;
  SDL_Renderer *renderer;

    

  if(SDL_Init(SDL_INIT_VIDEO) >= 0){
  
    SDL_DisplayMode mode;
    SDL_GetDisplayMode(0, 0, &mode);
    //printf("%dx%d\n", mode.w, mode.h);
    window_width = mode.h;
    window_height = mode.w;
  
    
  
    window = SDL_CreateWindow(NULL, 0,
			      0, window_width, window_height,
			      SDL_WINDOW_OPENGL | SDL_WINDOW_SHOWN | SDL_WINDOW_BORDERLESS);
  }

  if(window != 0){
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED |
				  SDL_RENDERER_PRESENTVSYNC);
  }
  
  /* Create a player */
  Player player;
  player.x = window_width / 2 - PLATE_WIDTH;
  player.y = window_height - PLATE_HEIGHT - PLAYER_OFFSET;
  player.hits = 0;
  player.score = 0;
  
  /* Create the enemy! */
  Player enemy;
  enemy.x = window_width / 2 - PLATE_WIDTH;
  enemy.y = PLAYER_OFFSET;
  enemy.hits = 0;
  
  Ball ball;
  ball.x = window_width / 2.0 - BALL_SIZE / 2.0;
  ball.y = window_height / 2.0 - BALL_SIZE / 2.0;
  ball.size = BALL_SIZE;
  ball.dx = -INITIAL_SPEED;
  ball.dy = !SERVER ? -INITIAL_SPEED : INITIAL_SPEED;
  
   
  
    
    
    if(SERVER){
        int port = argc == 2 ? strtol(argv[1], NULL, 10) : DEFAULT_PORT;
        listener_d = open_listener_socket();
        
        if(listener_d == -1){
            perror("Can't open the socket");
            exit(1);
        }
        
        
        
        if(bind_to_port(listener_d, port) == -1){
            perror("Can't bind");
            exit(2);
        }
        
        if(listen(listener_d, 1) == -1){
            perror("Can't listen");
            exit(3);
        }
        
        
        
        struct sockaddr_storage client_addr;
        unsigned int address_size = sizeof(client_addr);
        
        connect_d = accept(listener_d, (struct sockaddr*) &client_addr, &address_size);
        if(connect_d == -1){
            perror("Can't open secondary socked");
            exit(4);
        }
        
    }else{
        listener_d = socket(PF_INET, SOCK_STREAM, 0);
        
        struct sockaddr_in si;
        memset(&si, 0, sizeof(si));
        si.sin_family = PF_INET;
        si.sin_addr.s_addr = inet_addr("192.168.0.108");
        // si.sin_addr.s_addr = inet_addr(argv[1]);
        si.sin_port = htons(DEFAULT_PORT);
        connect(listener_d, (struct sockaddr*) &si, sizeof(si));

        //
        
            }
    params args = { &ball, &player, &enemy };
    
    
    
    SDL_Thread *updateThread = NULL;
    
    updateThread = SDL_CreateThread(UpdateThread, "UpdateThread", &args);
    SDL_Thread *handleThread = NULL;
    
    handleThread = SDL_CreateThread(HandleThread, "HandleThread", &player);
    
    while(running){
        handleEvents(&player);
        // update(&player, &enemy, &ball);
        render(renderer, &player, &enemy, &ball);
    }
  printf("Game Over\nYour Score: %d\n", player.score * SCORE_PER_HIT);
  return 0;
  clean(window, renderer);
}

void handleEvents(Player *player){
  SDL_Event event;
  while(SDL_PollEvent(&event)){
    switch(event.type){
        case SDL_FINGERDOWN:
        case SDL_FINGERMOTION:
                if (player->x + event.tfinger.dx * window_width < 0) {
                    player->x = 0;
                } else if((player->x + PLATE_WIDTH) > window_width){
                    printf("X: %f\n", event.tfinger.x * window_width);
                    //player->x += event.tfinger.dx * WINDOW_WIDTH;
                    player->x = window_width - PLATE_WIDTH;
                } else {
                    player->x += event.tfinger.dx * window_width;
                }
            stateChanged = 1;
        break;
        case SDL_FINGERUP:
            stateChanged = 0;
            break;
    case SDL_QUIT:
      running = 0;
      break;   
    case SDL_KEYDOWN:
      switch(event.key.keysym.sym){
      case SDLK_ESCAPE:
	running = 0;
	break;
      case SDLK_q:
	running = 0;
	break;
      }
      break;    
    }
  }

  const Uint8 *state = SDL_GetKeyboardState(NULL);
  if(state[SDL_SCANCODE_RIGHT]){
    if((player->x + PLATE_WIDTH + 2) <= window_width){
      player->x += 3;
    }
  }

  if(state[SDL_SCANCODE_LEFT]){
    if((player->x - 3) >= 0){
      player->x -= 3;
    }
  }
}

void update(Player *player, Player *enemy,  Ball *ball){
    if(ball->x < 0 || ball->x > window_width - ball->size){
        ball->dx = -ball->dx;
    }
    
    /* Enemy intelligence */
    // think(enemy, ball->x, window_width);
    char buf[255];
    
    if (SERVER) {
       read_in(connect_d, buf, 255);
    } else {
       read_in(listener_d, buf, 255);
    }
    
    
    
    player2(enemy, buf);
    if(ball->y < PLAYER_OFFSET + PLATE_HEIGHT ){
        /* Check if the enemy caught the ball */
        if((ball->x >= enemy->x) && ((ball->x + ball->size) <= (enemy->x + PLATE_WIDTH))){
            ball->dy = -(ball->dy);
            (enemy->hits)++;
            /* Increase ball speed every fifth hit */
            if(player->hits  == REQUIRED_HITS){
                // speedUp(ball);
                player->hits = 0;
            }

        }else{
            /* Enemy missed the ball! */
            player->score++;
            ball->x = window_width / 2.0 - BALL_SIZE / 2.0;
            ball->y = window_height / 2.0 - BALL_SIZE / 2.0;
            ball->dx = -INITIAL_SPEED;
            ball->dy = !SERVER ? -INITIAL_SPEED : INITIAL_SPEED;
            
        }
    }
    
    if((ball->y + ball->size) > window_height  - PLATE_HEIGHT - PLAYER_OFFSET){
        /* Check if the player caught the ball */
        if((ball->x >= player->x) && ((ball->x + ball->size) <= (player->x + PLATE_WIDTH))){
            // ball hit the surface of the paddle
            ball->dy = -(ball->dy);
            (player->hits)++;
                    }else {
            /* Player missed the ball! */
            if(player->score > 0){
                player->score--;
            }
            ball->x = window_width / 2.0 - BALL_SIZE / 2.0;
            ball->y = window_height / 2.0 - BALL_SIZE / 2.0;
            ball->dx = -INITIAL_SPEED;
            ball->dy = !SERVER ? -INITIAL_SPEED : INITIAL_SPEED;
            
                        
        }
    }
    ball->x += ball->dx;
    ball->y += ball->dy;
}

void render(SDL_Renderer *renderer, Player *player, Player *enemy, Ball *ball){
  // show blue background
  SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0xFF, 0xFF);
  SDL_RenderClear(renderer);
  
  SDL_SetRenderDrawColor(renderer, 255, 255, 255, 0xFF);
  
  SDL_Rect playerRect = {player->x, player->y, PLATE_WIDTH , PLATE_HEIGHT };
  SDL_Rect enemyRect = {enemy->x, enemy->y, PLATE_WIDTH , PLATE_HEIGHT };
  SDL_Rect ballRect = {ball->x, ball->y, ball->size, ball->size};

  SDL_RenderFillRect(renderer, &playerRect);
  SDL_RenderFillRect(renderer, &enemyRect);
  SDL_RenderFillRect(renderer, &ballRect);
  
  SDL_RenderPresent(renderer);
}

void clean(SDL_Window *window, SDL_Renderer *renderer){
  SDL_DestroyWindow(window);
  SDL_DestroyRenderer(renderer);
  SDL_Quit();
}
