%{
#include <math.h>  /* For math functions, cos(), sin(), etc.  */
#include <stdio.h>
#include <string.h>
#include <complex>
#include "symrec.h"
#include "functions.h"

  static const char* PROMPT_STRING = ">";
  class DavidException;
  int yylex (void);
  extern char* yytext;
  void yyerror (char const *);
  void do_command(const char*);
  void do_funct(symrec* fnct, symrec* param, double result[2]);
  void do_funct(symrec* fnct, double param[2], double result[2]);
  void do_funct2(symrec* fnct, symrec* param, symrec* param2, double result[2]);
  int update_vars(symrec* var);
  void handle_plane(symrec *rec,double& i, double& j, double result[2]);
  double ans[2];
  void print_complex(double cnumber[2]);

 %}
%union {
  double    val[2];   /* For returning numbers.  */
  struct symrec  *tptr;   /* For returning symbol-table pointers.  */
}
%token <val>  NUM        /* Simple double precision number.  */
%token <tptr> VAR FNCT 
%token IMAG EXIT
%type  <val>  exp
%left ANS
%right '='
%left '-' '+'
%left '*' '/'
%left NEG     /* negation--unary minus */
%right '^'    /* exponentiation */

%% /* The grammar follows.  */
input:   input stmt
        | /* NULL */
     ;
     
     stmt:
               ';'
               | EXIT ';' {YYACCEPT;}
               | exp ';'   { print_complex($1); ans = $1;}
               | error ';' { yyerrok;  printf("%s",PROMPT_STRING)         }
               ;

exp:          NUM                 { $$ = $1;yylval.val = $1;}
             | NUM IMAG { yylval.val[0] = 0;yylval.val[1] = $1[0];$$ = yylval.val;}
             | VAR                { $$ = $1->value.var;}
             | ANS                { $$ = ans;             } 
             | VAR '=' exp        { $$ = $3; $1->value.var = $3; }
             | FNCT '(' VAR ')'   { do_funct($1,$3,ans); $$ = ans;}
             | FNCT '(' exp ')'   { do_funct($1,$3,ans); $$ = ans;}
             | FNCT '(' VAR ',' VAR ')' { do_funct2($1, $3, $5,ans); $$ = ans;}
             | exp '+' exp        { $$[0] = $1[0] + $3[0];$$[1] = $1[1]+$3[1];}
             | exp '-' exp        { $$[0] = $1[0] - $3[0];$$[1] = $1[1]-$3[1];}
             | exp '*' exp        { $$[0] = $1[0] * $3[0]-$1[1]*$3[1];$$[1] = $1[0]*$3[1]+$1[1]*$3[0];}
             | exp '/' exp        { $$[0] = $1[0] / $3[0]; $$[1] = $1[1]/$3[0];}
             | exp '%' exp        { $$[0] = (int)$1[0] % (int)$3[0];}
             | '-' exp  %prec NEG { $$[0] = -$2[0];$$[1] = -$2[1];         }
             | exp '^' exp        { $$[0] = pow ($1[0], $3[0]);$$[1]=0; }
             | '(' exp ')'        { $$ = $2;                         }
             | VAR '[' exp ',' exp ']' {handle_plane($1,$3[0],$5[0],ans);$$ = ans;} 
            ;
     /* End of grammar.  */
%%

symrec *
     putsym (char const *sym_name, int sym_type)
     {
       symrec *ptr;
       ptr = (symrec *) malloc (sizeof (symrec));
       ptr->name = (char *) malloc (strlen (sym_name) + 1);
       strcpy (ptr->name,sym_name);
       ptr->type = sym_type;
       ptr->value.var[0] = 0; /* Set value to 0 even if fctn.  */
       ptr->value.var[1] = 0;
       ptr->next = (struct symrec *)sym_table;
       sym_table = ptr;
       return ptr;
     }
     
     symrec *
     getsym (char const *sym_name)
     {
       symrec *ptr;
       for (ptr = sym_table; ptr != (symrec *) 0;
            ptr = (symrec *)ptr->next)
         if (strcmp (ptr->name,sym_name) == 0)
           return ptr;
       return 0;
     }

#include <ctype.h>
#if 0     
     int
     yylex (void)
     {
       int c;

       /* Ignore white space, get first nonwhite character.  */
       while ((c = getchar ()) == ' ' || c == '\t');
     
       if (c == EOF)
         return 0;
     
       /* Char starts a number => parse the number.         */
       if (c == '.' || isdigit (c))
         {
           ungetc (c, stdin);
           scanf ("%lf", &yylval.val[0]);
           return NUM;
         }
     
       /* Char starts an identifier => read the name.       */
       if (isalpha (c))
         {
           symrec *s;
           static char *symbuf = 0;
           static int length = 0;
           int i;
     
           /* Initially make the buffer long enough
              for a 40-character symbol name.  */
           if (length == 0)
             length = 40, symbuf = (char *)malloc (length + 1);
     
           i = 0;
           do
             {
               /* If buffer is full, make it bigger.        */
               if (i == length)
                 {
                   length *= 2;
                   symbuf = (char *) realloc (symbuf, length + 1);
                 }
               /* Add this character to the buffer.         */
               symbuf[i++] = c;
               /* Get another character.                    */
               c = getchar ();
             }
           while (isalnum (c));
     
           ungetc (c, stdin);
           symbuf[i] = '\0';
     
           s = getsym (symbuf);
           if (s == 0)
             s = putsym (symbuf, VAR);
           yylval.tptr = s;
           return s->type;
         }
     
       /* Any other character is a token by itself.        */
       return c;
     }
#endif

/* Called by yyparse on error.  */
     void
     yyerror (char const *s)
     {
       printf ("%s: %s\n", s,yytext);
     }
     
     struct init
     {
       char const *fname;
       double (*fnct) (double);
     };
     
     struct init const arith_fncts[] =
     {
       "sin",  sin,
       "cos",  cos,
       "tan",  tan,
       "asin", asin,
       "acos", acos,
       "atan", atan,
       "ln",   log,
       "exp",  exp,
       "sqrt", sqrt,
       "floor", floor,
       "ceil", ceil,
       0, 0
     };
     
     /* The symbol table: a chain of `struct symrec'.  */
     symrec *sym_table;
     
/**
 * Initialize function table
 */
     void
     init_table (void)
     {
       int i;
       symrec *ptr;
       for (i = 0; arith_fncts[i].fname != 0; i++)
         {
           ptr = putsym (arith_fncts[i].fname, FNCT);
           ptr->value.fnctptr = arith_fncts[i].fnct;
           ptr->plane_fnctptr = NULL;
         }
       putsym("print",FNCT)->plane_fnctptr = print_plane;
       putsym("clear",FNCT)->plane_fnctptr = clear_plane;
       putsym("add",FNCT)->plane_fnctptr = add_planes;
       putsym("subtract",FNCT)->plane_fnctptr = subtract_planes;
       putsym("multiply",FNCT)->plane_fnctptr = multiply_planes;
       putsym("open",FNCT)->plane_fnctptr = open_plane;
       putsym("save",FNCT)->plane_fnctptr = save_plane;
       putsym("copy",FNCT)->plane_fnctptr = copy_plane;
       putsym("fourier",FNCT)->plane_fnctptr = fourier_plane;
       putsym("ifourier",FNCT)->plane_fnctptr = ifourier_plane;
     }
     
     int
     main (void)
     {
       symrec *funct;
       init_table ();
       printf("\n");
       printf("Welcome! To exit, type quit.\nAll statements must end with a semicolon.\n%s",PROMPT_STRING);
       yyparse();
       printf("Good bye.\n");
       return 0;
     }

void do_funct(symrec *rec, double param[2], double result[2])
{
  if(rec == NULL || rec->plane_fnctptr != NULL)
    return;
    
  result[0] = (*(rec->value.fnctptr))(param[0]);      
  result[1] = 0.0;
}

void do_funct(symrec *rec, symrec *param, double result[2])
{
  if(rec == NULL || param == NULL)
    return;

  if(rec->plane_fnctptr != NULL)
    {
      symrec* newrec = (*rec->plane_fnctptr)(&param,1);
      if(newrec != NULL)
	{
	  newrec->next = (struct symrec *)sym_table;
	  sym_table = newrec;
	}
       return;
    }
  result[0] = (*(rec->value.fnctptr))(param->value.var[0]);
  result[1] = 0.0;
}


void do_funct2(symrec* rec, symrec* param, symrec* param2, double result[2])
{
  if(rec == NULL || param == NULL || param2 == NULL)
    return;
  if(rec->plane_fnctptr == NULL)
    return;

  symrec* params[] = {param,param2};
  symrec* newrec = (*rec->plane_fnctptr)(params,2);
  if(newrec != NULL)
    {
      newrec->next = (struct symrec *)sym_table;
      sym_table = newrec;
    }

}

void handle_plane(symrec *rec,double& i, double& j, double result[2])
{
  rec->isPlane = true;
  if(rec->value.planeptr == NULL)
    {
      rec->value.planeptr = create_plane(i,j); 
      return;
    }
  try{
    const Double& complex = rec->value.planeptr->getValue((int)i,(int)j);
    result[0] = complex.getValue(0);
    result[1] = complex.getValue(1);
  }
  catch(DavidException de)
    {
      std::cout << de.what() << std::endl;
    }
}

void print_complex(double cnumber[2])
{
  using namespace std;
  cout << "\tans: ";
  if(cnumber[1] != 0)
    {
      math::Complex buff(cnumber[0],cnumber[1]);
      cout << buff;
    }
  else
    cout << cnumber[0];
  cout <<   endl << ">";
}
