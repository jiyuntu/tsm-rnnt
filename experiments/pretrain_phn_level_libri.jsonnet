local BATCH_SIZE = 8;
local FRAME_RATE = 1;
local ENCODER_HIDDEN_SIZE = 320;
local DECODER_HIDDEN_SIZE = 320;
local VOCAB_PATH = "runs/pretrain_phn_level_libri/vocabulary";
local NUM_GPUS = 1;
local TARGET_NAMESPACE = "target_tokens";
local PHN_TARGET_NAMESPACE = "phn_target_tokens";
local NUM_THREADS = 4;
local VGG = true;
local OUT_CHANNEL = 128;
local STACK_RATE = if VGG then 4 else 1;
local VGG_OUTPUT_SIZE = 80 * (if VGG then (OUT_CHANNEL / STACK_RATE) else 1) * FRAME_RATE;


local BASE_ITERATOR = {
  "type": "homogeneous_batch",
  "max_instances_in_memory": 24 * NUM_GPUS,
  "batch_size": BATCH_SIZE,
  // "sorting_keys": [["source_features", "dimension_0"],
  //                   #[TARGET_NAMESPACE, "num_tokens"]],
  //                  [PHN_TARGET_NAMESPACE, "num_tokens"]],
//   "maximum_samples_per_batch": ["dimension_0", 6400],
  "track_epoch": true
};

local TSM_READER = {
  "type": "mao-stt",
  "lazy": true,
  "mmap": true,
  "shard_size": BATCH_SIZE,
  "input_stack_rate": FRAME_RATE,
  "model_stack_rate": STACK_RATE,
  "bucket": true,
  "is_phone": false,
  "target_add_start_end_token": true,
  "target_tokenizer": {
    "type": "word",
    "word_splitter": {
      "type": "just_spaces"
    }
  },
  "target_token_indexers": {
    "tokens": {
      "type": "single_id",        
      "namespace": TARGET_NAMESPACE
    }
  }
};


local PHN_READER = {
  "type": "mao-stt",
  "lazy": true,
  "mmap": true,
  "shard_size": BATCH_SIZE,
  "input_stack_rate": FRAME_RATE,
  "model_stack_rate": STACK_RATE,
  "bucket": true,
  "is_phone": false,
  "target_add_start_end_token": false,
  "target_tokenizer": {
    "type": "word",
    "word_splitter": {
      "type": "just_spaces"
    }
  },
  "target_token_indexers": {
    "tokens": {
      "type": "single_id",        
      "namespace": PHN_TARGET_NAMESPACE
    }
  }
};

{
  "random_seed": 13370,
  "numpy_seed": 1337,
  "pytorch_seed": 133,
  "dataset_reader": {
      "type": "interleaving",
      "readers": {
          "phn_train_clean_100": PHN_READER,
          "phn_train_clean_360": PHN_READER,
          "phn_train_other_500": PHN_READER
      },
      "lazy": true
  },
  "validation_dataset_reader": {
      "type": "interleaving",
      "readers": {
          "phn_dev_clean": PHN_READER,
          "phn_dev_other": PHN_READER
      },
      "lazy": true
  },
  "vocabulary": {
  "directory_path": VOCAB_PATH
  },
  "train_data_path": |||
    {
        "phn_train_clean_100": "/home/nlpmaster/ssd-1t/corpus/LibriSpeech/train-clean-100",
        "phn_train_clean_360": "/home/nlpmaster/ssd-1t/corpus/LibriSpeech/train-clean-360",
        "phn_train_other_500": "/home/nlpmaster/ssd-1t/corpus/LibriSpeech/train-other-500"
    }
  |||,
  "validation_data_path": |||
    {
        "phn_dev_clean": "/home/nlpmaster/ssd-1t/corpus/LibriSpeech/dev-clean",
        "phn_dev_other": "/home/nlpmaster/ssd-1t/corpus/LibriSpeech/dev-other"
    }
  |||,
  "model": {
    "type": "phn_mocha",
    "input_size": 80 * FRAME_RATE,
    "cmvn": true,
    "from_candidates": false,
    "sampling_strategy": "max",
    // "encoder": {
    //   "type": "awd-rnn",
    //   "input_size": 80 * FRAME_RATE,
    //   "hidden_size": ENCODER_HIDDEN_SIZE,
    //   "num_layers": 5,
    //   "dropout": 0.5,
    //   "dropouth": 0.5,
    //   "dropouti": 0.5,
    //   "wdrop": 0.0,
    //   "stack_rates": [1, 1, 1, 1, 1],
    // },
    // "encoder": {
    //   "type": "lstm",
    //   "input_size": VGG_OUTPUT_SIZE,
    //   "hidden_size": ENCODER_HIDDEN_SIZE,
    //   "num_layers": 5,
    //   "bidirectional": true,
    //   "dropout": 0.3
    // },
    "encoder": {
      "type": "residual_bidirectional_lstm",
      "input_size": VGG_OUTPUT_SIZE,
      "hidden_size": ENCODER_HIDDEN_SIZE,
      "num_layers": 8,
      "layer_dropout_probability": 0.3,
      "use_residual": true
    },
    
    "dropout": 0.3,
    "has_vgg": VGG,
    "vgg_out_channel": OUT_CHANNEL,
    // "encoder": {
    //   "type": "pass_through",
    //   "input_dim": ENCODER_OUTPUT_SIZE
    // },
    "max_decoding_steps": 30,
    "target_embedding_dim": DECODER_HIDDEN_SIZE,
    "beam_size": 5,
    // "attention": {
    //   "type": "mocha",
    //   "chunk_size": 3,
    //   "enc_dim": ENCODER_OUTPUT_SIZE,
    //   "dec_dim": DECODER_HIDDEN_SIZE,
    //   "att_dim": DECODER_HIDDEN_SIZE
    //   #"dirac_at_first_step": false
    // },
    "attention": {
      "type": "bilinear",
      "vector_dim": DECODER_HIDDEN_SIZE,
      "matrix_dim": ENCODER_HIDDEN_SIZE
    },
    "n_pretrain_ctc_epochs": 2,
    "target_namespace": TARGET_NAMESPACE,
    "phoneme_target_namespace": PHN_TARGET_NAMESPACE,
    "initializer": [
      [".*linear.*weight", {"type": "xavier_uniform"}],
      [".*linear.*bias", {"type": "zero"}],
      [".*weight_ih.*", {"type": "xavier_uniform"}],
      [".*weight_hh.*", {"type": "orthogonal"}],
      [".*bias_ih.*", {"type": "zero"}],
      [".*bias_hh.*", {"type": "lstm_hidden_bias"}],
      ["_target_embedder.weight", {"type": "uniform", "a": -1, "b": 1}],
    ]
  },
  // "iterator": {
  //   "type": "bucket",
  //   "padding_noise": 0.0,
  //   "batch_size" : BATCH_SIZE,
  //   "sorting_keys": [["source_features", "dimension_0"],
  //                    ["target_tokens", "num_tokens"]],
  //   "track_epoch": true
  // },
  "iterator": BASE_ITERATOR,
//   "iterator": {
//     "type": "multiprocess",
//     "base_iterator": BASE_ITERATOR,
//     "num_workers": NUM_THREADS,
//     "output_queue_size": 1024
//   },
  "trainer": {
    "num_epochs": 300,
    "patience": 20,
    "grad_norm": 5.0,
    "cuda_device": 0,
    "validation_metric": "-PHN_WER",
    "num_serialized_models_to_keep": 1,
    "should_log_learning_rate": true,
    // "learning_rate_scheduler": {
    //   "type": "reduce_on_plateau",
    //   "factor": 0.8,
    //   "mode": "min",
    //   "patience": 10
    // },
    // "learning_rate_scheduler": {
    //   "type": "multi_step",
    //   "milestones": [54, 68, 84],
    //   "gamma": 0.5,
    // },
    "learning_rate_scheduler": {
      "type": "multi_step",
      "milestones": [48, 60, 72],
      "gamma": 0.5,
    },
    "optimizer": {
      "type": "adamw",
      "lr": 0.0003,
      "amsgrad": true,
      "weight_decay": 0.01
    }
  }
}
