#include <expat.h>
#include <stdio.h>
#include <string.h>

#ifdef XML_LARGE_SIZE
#define XML_FMT_INT_MOD "ll"
#else
#define XML_FMT_INT_MOD "l"
#endif

#ifdef XML_UNICODE_WCHAR_T
#define XML_FMT_STR "ls"
#else
#define XML_FMT_STR "s"
#endif

struct ParserData {
  size_t num_nodes;
  size_t num_way;
  size_t node_refs;
};

static void XMLCALL startElement(void *userData, const XML_Char *name,
                                 const XML_Char **atts) {
  int i;
  struct ParserData *parser_data = (struct ParserData *)userData;
  (void)atts;

  if (strcasecmp("node", name) == 0)
    parser_data->num_nodes += 1;
  else if (strcasecmp("way", name) == 0)
    parser_data->num_way += 1;
  else if(strcasecmp("nd", name) == 0)
    parser_data->node_refs += 1;
}

static void XMLCALL endElement(void *userData, const XML_Char *name) {
  int *const depthPtr = (int *)userData;
  (void)name;

  *depthPtr -= 1;
}

int main(int argc, char **argv) {
  XML_Parser parser = XML_ParserCreate(NULL);
  int done;
  int depth = 0;

  if (argc < 2) {
    fprintf(stderr, "not enough args\n");
    return 1;
  }

  FILE *file = fopen(argv[1], "r");

  if (!parser) {
    fprintf(stderr, "Couldn't allocate memory for parser\n");
    return 1;
  }

  struct ParserData data = {0};
  XML_SetUserData(parser, &data);
  XML_SetElementHandler(parser, startElement, endElement);

  int i = 0;
  do {
    i += 1;
    if (i % 100) {
      printf("nodes: %lu, ways: %lu, refs:%lu\n", data.num_nodes, data.num_way, data.node_refs);
    }

    void *const buf = XML_GetBuffer(parser, BUFSIZ);
    if (!buf) {
      fprintf(stderr, "Couldn't allocate memory for buffer\n");
      XML_ParserFree(parser);
      return 1;
    }

    const size_t len = fread(buf, 1, BUFSIZ, file);

    if (ferror(stdin)) {
      fprintf(stderr, "Read error\n");
      XML_ParserFree(parser);
      return 1;
    }

    done = feof(stdin);

    if (XML_ParseBuffer(parser, (int)len, done) == XML_STATUS_ERROR) {
      fprintf(stderr,
              "Parse error at line %" XML_FMT_INT_MOD "u:\n%" XML_FMT_STR "\n",
              XML_GetCurrentLineNumber(parser),
              XML_ErrorString(XML_GetErrorCode(parser)));
      XML_ParserFree(parser);
      return 1;
    }
  } while (!done);

  XML_ParserFree(parser);
  return 0;
}
